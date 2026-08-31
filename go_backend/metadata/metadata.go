package metadata

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

var (
	ErrUnsupportedFormat = errors.New("metadata: unsupported format")
	ErrTagNotFound       = errors.New("metadata: tag not found")
	ErrWriteFailed       = errors.New("metadata: write failed")
	ErrInvalidTag        = errors.New("metadata: invalid tag")
)

type Format string

const (
	FormatFLAC  Format = "flac"
	FormatMP3   Format = "mp3"
	FormatM4A   Format = "m4a"
	FormatOGG   Format = "ogg"
	FormatOPUS  Format = "opus"
	FormatWAV   Format = "wav"
	FormatAIFF  Format = "aiff"
	FormatALAC  Format = "alac"
	FormatDSD   Format = "dsd"
)

type Tag struct {
	Title       string
	Artist      string
	Album       string
	AlbumArtist string
	Composer    string
	Genre       string
	Year        int
	TrackNumber int
	TotalTracks int
	DiscNumber  int
	TotalDiscs  int
	Duration    time.Duration
	BPM         int
	ISRC        string
	Lyrics      string
	CoverArt    []CoverArt
	Custom      map[string]string
}

type CoverArt struct {
	Data        []byte
	MimeType    string
	Description string
	IsFront     bool
}

type Metadata struct {
	Format     Format
	FilePath   string
	FileSize   int64
	Tags       Tag
	Technical  TechnicalInfo
}

type TechnicalInfo struct {
	SampleRate     int
	BitDepth       int
	Channels       int
	Bitrate        int
	Codec          string
	Duration       time.Duration
	Frames         int64
}

type Reader interface {
	Read(ctx context.Context, path string) (*Metadata, error)
	ReadTags(ctx context.Context, path string) (Tag, error)
	ReadTechnical(ctx context.Context, path string) (TechnicalInfo, error)
	SupportsFormat(format Format) bool
}

type Writer interface {
	Write(ctx context.Context, path string, tags Tag) error
	WriteCoverArt(ctx context.Context, path string, cover CoverArt) error
	RemoveCoverArt(ctx context.Context, path string) error
	SupportsFormat(format Format) bool
}

type Processor interface {
	Reader
	Writer
	DetectFormat(path string) (Format, error)
}

type Registry struct {
	readers map[Format]Reader
	writers map[Format]Writer
	mu      sync.RWMutex
}

func NewRegistry() *Registry {
	return &Registry{
		readers: make(map[Format]Reader),
		writers: make(map[Format]Writer),
	}
}

func (r *Registry) RegisterReader(format Format, reader Reader) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.readers[format] = reader
}

func (r *Registry) RegisterWriter(format Format, writer Writer) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.writers[format] = writer
}

func (r *Registry) RegisterProcessor(format Format, processor Processor) {
	r.RegisterReader(format, processor)
	r.RegisterWriter(format, processor)
}

func (r *Registry) GetReader(format Format) (Reader, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	reader, ok := r.readers[format]
	return reader, ok
}

func (r *Registry) GetWriter(format Format) (Writer, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	writer, ok := r.writers[format]
	return writer, ok
}

func (r *Registry) DetectFormat(path string) (Format, error) {
	ext := strings.ToLower(filepath.Ext(path))
	switch ext {
	case ".flac":
		return FormatFLAC, nil
	case ".mp3":
		return FormatMP3, nil
	case ".m4a", ".mp4":
		return FormatM4A, nil
	case ".ogg":
		return FormatOGG, nil
	case ".opus":
		return FormatOPUS, nil
	case ".wav":
		return FormatWAV, nil
	case ".aiff", ".aif":
		return FormatAIFF, nil
	default:
		return "", ErrUnsupportedFormat
	}
}

func (r *Registry) Read(ctx context.Context, path string) (*Metadata, error) {
	format, err := r.DetectFormat(path)
	if err != nil {
		return nil, err
	}

	reader, ok := r.GetReader(format)
	if !ok {
		return nil, fmt.Errorf("%w: %s", ErrUnsupportedFormat, format)
	}

	return reader.Read(ctx, path)
}

func (r *Registry) Write(ctx context.Context, path string, tags Tag) error {
	format, err := r.DetectFormat(path)
	if err != nil {
		return err
	}

	writer, ok := r.GetWriter(format)
	if !ok {
		return fmt.Errorf("%w: %s", ErrUnsupportedFormat, format)
	}

	return writer.Write(ctx, path, tags)
}

type Service struct {
	registry *Registry
}

func NewService() *Service {
	registry := NewRegistry()
	return &Service{
		registry: registry,
	}
}

func (s *Service) Read(ctx context.Context, path string) (*Metadata, error) {
	return s.registry.Read(ctx, path)
}

func (s *Service) Write(ctx context.Context, path string, tags Tag) error {
	return s.registry.Write(ctx, path, tags)
}

func (s *Service) ReadTags(ctx context.Context, path string) (Tag, error) {
	format, err := s.registry.DetectFormat(path)
	if err != nil {
		return Tag{}, err
	}

	reader, ok := s.registry.GetReader(format)
	if !ok {
		return Tag{}, fmt.Errorf("%w: %s", ErrUnsupportedFormat, format)
	}

	return reader.ReadTags(ctx, path)
}

func (s *Service) WriteTags(ctx context.Context, path string, tags Tag) error {
	return s.registry.Write(ctx, path, tags)
}

func (s *Service) EmbedCoverArt(ctx context.Context, path string, cover CoverArt) error {
	format, err := s.registry.DetectFormat(path)
	if err != nil {
		return err
	}

	writer, ok := s.registry.GetWriter(format)
	if !ok {
		return fmt.Errorf("%w: %s", ErrUnsupportedFormat, format)
	}

	return writer.WriteCoverArt(ctx, path, cover)
}

func (s *Service) ExtractCoverArt(ctx context.Context, path string) ([]CoverArt, error) {
	metadata, err := s.Read(ctx, path)
	if err != nil {
		return nil, err
	}
	return metadata.Tags.CoverArt, nil
}

func (s *Service) EmbedLyrics(ctx context.Context, path string, lyrics string) error {
	tags, err := s.ReadTags(ctx, path)
	if err != nil {
		return err
	}

	tags.Lyrics = lyrics
	return s.Write(ctx, path, tags)
}

func (s *Service) ExtractLyrics(ctx context.Context, path string) (string, error) {
	tags, err := s.ReadTags(ctx, path)
	if err != nil {
		return "", err
	}
	return tags.Lyrics, nil
}

func (s *Service) GetTechnicalInfo(ctx context.Context, path string) (TechnicalInfo, error) {
	format, err := s.registry.DetectFormat(path)
	if err != nil {
		return TechnicalInfo{}, err
	}

	reader, ok := s.registry.GetReader(format)
	if !ok {
		return TechnicalInfo{}, fmt.Errorf("%w: %s", ErrUnsupportedFormat, format)
	}

	return reader.ReadTechnical(ctx, path)
}

type FLACReader struct{}

func NewFLACReader() *FLACReader { return &FLACReader{} }

func (r *FLACReader) SupportsFormat(format Format) bool {
	return format == FormatFLAC
}

func (r *FLACReader) Read(ctx context.Context, path string) (*Metadata, error) {
	return nil, ErrUnsupportedFormat
}

func (r *FLACReader) ReadTags(ctx context.Context, path string) (Tag, error) {
	return Tag{}, ErrUnsupportedFormat
}

func (r *FLACReader) ReadTechnical(ctx context.Context, path string) (TechnicalInfo, error) {
	return TechnicalInfo{}, ErrUnsupportedFormat
}

type FLACWriter struct{}

func NewFLACWriter() *FLACWriter { return &FLACWriter{} }

func (w *FLACWriter) SupportsFormat(format Format) bool {
	return format == FormatFLAC
}

func (w *FLACWriter) Write(ctx context.Context, path string, tags Tag) error {
	return ErrUnsupportedFormat
}

func (w *FLACWriter) WriteCoverArt(ctx context.Context, path string, cover CoverArt) error {
	return ErrUnsupportedFormat
}

func (w *FLACWriter) RemoveCoverArt(ctx context.Context, path string) error {
	return ErrUnsupportedFormat
}

type MP3Reader struct{}

func NewMP3Reader() *MP3Reader { return &MP3Reader{} }

func (r *MP3Reader) SupportsFormat(format Format) bool {
	return format == FormatMP3
}

func (r *MP3Reader) Read(ctx context.Context, path string) (*Metadata, error) {
	return nil, ErrUnsupportedFormat
}

func (r *MP3Reader) ReadTags(ctx context.Context, path string) (Tag, error) {
	return Tag{}, ErrUnsupportedFormat
}

func (r *MP3Reader) ReadTechnical(ctx context.Context, path string) (TechnicalInfo, error) {
	return TechnicalInfo{}, ErrUnsupportedFormat
}

type MP3Writer struct{}

func NewMP3Writer() *MP3Writer { return &MP3Writer{} }

func (w *MP3Writer) SupportsFormat(format Format) bool {
	return format == FormatMP3
}

func (w *MP3Writer) Write(ctx context.Context, path string, tags Tag) error {
	return ErrUnsupportedFormat
}

func (w *MP3Writer) WriteCoverArt(ctx context.Context, path string, cover CoverArt) error {
	return ErrUnsupportedFormat
}

func (w *MP3Writer) RemoveCoverArt(ctx context.Context, path string) error {
	return ErrUnsupportedFormat
}

type M4AReader struct{}

func NewM4AReader() *M4AReader { return &M4AReader{} }

func (r *M4AReader) SupportsFormat(format Format) bool {
	return format == FormatM4A
}

func (r *M4AReader) Read(ctx context.Context, path string) (*Metadata, error) {
	return nil, ErrUnsupportedFormat
}

func (r *M4AReader) ReadTags(ctx context.Context, path string) (Tag, error) {
	return Tag{}, ErrUnsupportedFormat
}

func (r *M4AReader) ReadTechnical(ctx context.Context, path string) (TechnicalInfo, error) {
	return TechnicalInfo{}, ErrUnsupportedFormat
}

type M4AWriter struct{}

func NewM4AWriter() *M4AWriter { return &M4AWriter{} }

func (w *M4AWriter) SupportsFormat(format Format) bool {
	return format == FormatM4A
}

func (w *M4AWriter) Write(ctx context.Context, path string, tags Tag) error {
	return ErrUnsupportedFormat
}

func (w *M4AWriter) WriteCoverArt(ctx context.Context, path string, cover CoverArt) error {
	return ErrUnsupportedFormat
}

func (w *M4AWriter) RemoveCoverArt(ctx context.Context, path string) error {
	return ErrUnsupportedFormat
}

type OGGReader struct{}

func NewOGGReader() *OGGReader { return &OGGReader{} }

func (r *OGGReader) SupportsFormat(format Format) bool {
	return format == FormatOGG || format == FormatOPUS
}

func (r *OGGReader) Read(ctx context.Context, path string) (*Metadata, error) {
	return nil, ErrUnsupportedFormat
}

func (r *OGGReader) ReadTags(ctx context.Context, path string) (Tag, error) {
	return Tag{}, ErrUnsupportedFormat
}

func (r *OGGReader) ReadTechnical(ctx context.Context, path string) (TechnicalInfo, error) {
	return TechnicalInfo{}, ErrUnsupportedFormat
}

type OGGWriter struct{}

func NewOGGWriter() *OGGWriter { return &OGGWriter{} }

func (w *OGGWriter) SupportsFormat(format Format) bool {
	return format == FormatOGG || format == FormatOPUS
}

func (w *OGGWriter) Write(ctx context.Context, path string, tags Tag) error {
	return ErrUnsupportedFormat
}

func (w *OGGWriter) WriteCoverArt(ctx context.Context, path string, cover CoverArt) error {
	return ErrUnsupportedFormat
}

func (w *OGGWriter) RemoveCoverArt(ctx context.Context, path string) error {
	return ErrUnsupportedFormat
}

func (s *Service) RegisterDefaults() {
	s.registry.RegisterProcessor(FormatFLAC, &FLACProcessor{
		reader: NewFLACReader(),
		writer: NewFLACWriter(),
	})
	s.registry.RegisterProcessor(FormatMP3, &MP3Processor{
		reader: NewMP3Reader(),
		writer: NewMP3Writer(),
	})
	s.registry.RegisterProcessor(FormatM4A, &M4AProcessor{
		reader: NewM4AReader(),
		writer: NewM4AWriter(),
	})
	s.registry.RegisterProcessor(FormatOGG, &OGGProcessor{
		reader: NewOGGReader(),
		writer: NewOGGWriter(),
	})
	s.registry.RegisterProcessor(FormatOPUS, &OGGProcessor{
		reader: NewOGGReader(),
		writer: NewOGGWriter(),
	})
}

type FLACProcessor struct {
	reader *FLACReader
	writer *FLACWriter
}

func (p *FLACProcessor) SupportsFormat(format Format) bool { return format == FormatFLAC }
func (p *FLACProcessor) Read(ctx context.Context, path string) (*Metadata, error) { return p.reader.Read(ctx, path) }
func (p *FLACProcessor) ReadTags(ctx context.Context, path string) (Tag, error) { return p.reader.ReadTags(ctx, path) }
func (p *FLACProcessor) ReadTechnical(ctx context.Context, path string) (TechnicalInfo, error) { return p.reader.ReadTechnical(ctx, path) }
func (p *FLACProcessor) Write(ctx context.Context, path string, tags Tag) error { return p.writer.Write(ctx, path, tags) }
func (p *FLACProcessor) WriteCoverArt(ctx context.Context, path string, cover CoverArt) error { return p.writer.WriteCoverArt(ctx, path, cover) }
func (p *FLACProcessor) RemoveCoverArt(ctx context.Context, path string) error { return p.writer.RemoveCoverArt(ctx, path) }

type MP3Processor struct {
	reader *MP3Reader
	writer *MP3Writer
}

func (p *MP3Processor) SupportsFormat(format Format) bool { return format == FormatMP3 }
func (p *MP3Processor) Read(ctx context.Context, path string) (*Metadata, error) { return p.reader.Read(ctx, path) }
func (p *MP3Processor) ReadTags(ctx context.Context, path string) (Tag, error) { return p.reader.ReadTags(ctx, path) }
func (p *MP3Processor) ReadTechnical(ctx context.Context, path string) (TechnicalInfo, error) { return p.reader.ReadTechnical(ctx, path) }
func (p *MP3Processor) Write(ctx context.Context, path string, tags Tag) error { return p.writer.Write(ctx, path, tags) }
func (p *MP3Processor) WriteCoverArt(ctx context.Context, path string, cover CoverArt) error { return p.writer.WriteCoverArt(ctx, path, cover) }
func (p *MP3Processor) RemoveCoverArt(ctx context.Context, path string) error { return p.writer.RemoveCoverArt(ctx, path) }

type M4AProcessor struct {
	reader *M4AReader
	writer *M4AWriter
}

func (p *M4AProcessor) SupportsFormat(format Format) bool { return format == FormatM4A }
func (p *M4AProcessor) Read(ctx context.Context, path string) (*Metadata, error) { return p.reader.Read(ctx, path) }
func (p *M4AProcessor) ReadTags(ctx context.Context, path string) (Tag, error) { return p.reader.ReadTags(ctx, path) }
func (p *M4AProcessor) ReadTechnical(ctx context.Context, path string) (TechnicalInfo, error) { return p.reader.ReadTechnical(ctx, path) }
func (p *M4AProcessor) Write(ctx context.Context, path string, tags Tag) error { return p.writer.Write(ctx, path, tags) }
func (p *M4AProcessor) WriteCoverArt(ctx context.Context, path string, cover CoverArt) error { return p.writer.WriteCoverArt(ctx, path, cover) }
func (p *M4AProcessor) RemoveCoverArt(ctx context.Context, path string) error { return p.writer.RemoveCoverArt(ctx, path) }

type OGGProcessor struct {
	reader *OGGReader
	writer *OGGWriter
}

func (p *OGGProcessor) SupportsFormat(format Format) bool { return format == FormatOGG || format == FormatOPUS }
func (p *OGGProcessor) Read(ctx context.Context, path string) (*Metadata, error) { return p.reader.Read(ctx, path) }
func (p *OGGProcessor) ReadTags(ctx context.Context, path string) (Tag, error) { return p.reader.ReadTags(ctx, path) }
func (p *OGGProcessor) ReadTechnical(ctx context.Context, path string) (TechnicalInfo, error) { return p.reader.ReadTechnical(ctx, path) }
func (p *OGGProcessor) Write(ctx context.Context, path string, tags Tag) error { return p.writer.Write(ctx, path, tags) }
func (p *OGGProcessor) WriteCoverArt(ctx context.Context, path string, cover CoverArt) error { return p.writer.WriteCoverArt(ctx, path, cover) }
func (p *OGGProcessor) RemoveCoverArt(ctx context.Context, path string) error { return p.writer.RemoveCoverArt(ctx, path) }