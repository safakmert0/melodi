package matching

import (
	"errors"
	"fmt"
	"regexp"
	"sort"
	"strings"
	"unicode"
)

var (
	ErrNoMatch      = errors.New("matching: no suitable match found")
	ErrInvalidInput = errors.New("matching: invalid input")
)

type MatchResult struct {
	ID              string
	Title           string
	Artist          string
	Album           string
	Duration        int64
	ISRC            string
	Confidence      float64
	ScoreBreakdown  ScoreBreakdown
	MatchReasons    []string
}

type ScoreBreakdown struct {
	TitleScore     float64
	ArtistScore    float64
	AlbumScore     float64
	DurationScore  float64
	ISRCScore      float64
	TotalScore     float64
	Weights        ScoreWeights
}

type ScoreWeights struct {
	Title     float64
	Artist    float64
	Album     float64
	Duration  float64
	ISRC      float64
}

func DefaultScoreWeights() ScoreWeights {
	return ScoreWeights{
		Title:    0.40,
		Artist:   0.30,
		Album:    0.10,
		Duration: 0.10,
		ISRC:     0.10,
	}
}

type MatcherConfig struct {
	Weights              ScoreWeights
	MinConfidence        float64
	TitleThreshold       float64
	ArtistThreshold      float64
	DurationToleranceMs  int64
	EnableFuzzy          bool
	FuzzyThreshold       float64
}

func DefaultMatcherConfig() MatcherConfig {
	return MatcherConfig{
		Weights:             DefaultScoreWeights(),
		MinConfidence:       0.5,
		TitleThreshold:      0.7,
		ArtistThreshold:     0.7,
		DurationToleranceMs: 5000,
		EnableFuzzy:         true,
		FuzzyThreshold:      0.8,
	}
}

type Matcher struct {
	config MatcherConfig
	norm   *Normalizer
}

func NewMatcher(config MatcherConfig) *Matcher {
	if config.Weights.Title == 0 && config.Weights.Artist == 0 {
		config = DefaultMatcherConfig()
	}
	return &Matcher{
		config: config,
		norm:   NewNormalizer(),
	}
}

func (m *Matcher) Match(query TrackQuery, candidates []TrackCandidate) (*MatchResult, error) {
	if len(candidates) == 0 {
		return nil, ErrNoMatch
	}

	var bestMatch *MatchResult
	bestScore := 0.0

	for _, candidate := range candidates {
		result := m.scoreCandidate(query, candidate)
		if result.Confidence > bestScore {
			bestScore = result.Confidence
			bestMatch = result
		}
	}

	if bestMatch == nil || bestMatch.Confidence < m.config.MinConfidence {
		return nil, ErrNoMatch
	}

	return bestMatch, nil
}

func (m *Matcher) MatchBatch(query TrackQuery, candidates []TrackCandidate) ([]*MatchResult, error) {
	var results []*MatchResult

	for _, candidate := range candidates {
		result := m.scoreCandidate(query, candidate)
		if result.Confidence >= m.config.MinConfidence {
			results = append(results, result)
		}
	}

	sort.Slice(results, func(i, j int) bool {
		return results[i].Confidence > results[j].Confidence
	})

	if len(results) == 0 {
		return nil, ErrNoMatch
	}

	return results, nil
}

func (m *Matcher) scoreCandidate(query TrackQuery, candidate TrackCandidate) *MatchResult {
	breakdown := ScoreBreakdown{
		Weights: m.config.Weights,
	}

	breakdown.TitleScore = m.scoreTitle(query, candidate)
	breakdown.ArtistScore = m.scoreArtist(query, candidate)
	breakdown.AlbumScore = m.scoreAlbum(query, candidate)
	breakdown.DurationScore = m.scoreDuration(query, candidate)
	breakdown.ISRCScore = m.scoreISRC(query, candidate)

	total := breakdown.TitleScore*m.config.Weights.Title +
		breakdown.ArtistScore*m.config.Weights.Artist +
		breakdown.AlbumScore*m.config.Weights.Album +
		breakdown.DurationScore*m.config.Weights.Duration +
		breakdown.ISRCScore*m.config.Weights.ISRC

	breakdown.TotalScore = total

	reasons := m.generateReasons(query, candidate, breakdown)

	return &MatchResult{
		ID:             candidate.ID,
		Title:          candidate.Title,
		Artist:         candidate.Artist,
		Album:          candidate.Album,
		Duration:       candidate.Duration,
		ISRC:           candidate.ISRC,
		Confidence:     total,
		ScoreBreakdown: breakdown,
		MatchReasons:   reasons,
	}
}

func (m *Matcher) scoreTitle(query TrackQuery, candidate TrackCandidate) float64 {
	if query.Title == "" || candidate.Title == "" {
		return 0
	}

	normQuery := m.norm.NormalizeTitle(query.Title)
	normCandidate := m.norm.NormalizeTitle(candidate.Title)

	if normQuery == normCandidate {
		return 1.0
	}

	sim := m.norm.Similarity(normQuery, normCandidate)

	if m.config.EnableFuzzy && sim >= m.config.FuzzyThreshold {
		return sim * 0.95
	}

	contains := strings.Contains(normCandidate, normQuery) || strings.Contains(normQuery, normCandidate)
	if contains {
		return sim * 0.9
	}

	return sim
}

func (m *Matcher) scoreArtist(query TrackQuery, candidate TrackCandidate) float64 {
	if query.Artist == "" || candidate.Artist == "" {
		return 0
	}

	normQuery := m.norm.NormalizeArtist(query.Artist)
	normCandidate := m.norm.NormalizeArtist(candidate.Artist)

	if normQuery == normCandidate {
		return 1.0
	}

	queryParts := strings.Fields(normQuery)
	candidateParts := strings.Fields(normCandidate)

	matched := 0
	for _, qp := range queryParts {
		for _, cp := range candidateParts {
			if m.norm.Similarity(qp, cp) > 0.8 {
				matched++
				break
			}
		}
	}

	if len(queryParts) > 0 {
		partScore := float64(matched) / float64(len(queryParts))
		sim := m.norm.Similarity(normQuery, normCandidate)
		return (partScore + sim) / 2
	}

	return 0
}

func (m *Matcher) scoreAlbum(query TrackQuery, candidate TrackCandidate) float64 {
	if query.Album == "" || candidate.Album == "" {
		return 0.5
	}

	normQuery := m.norm.NormalizeTitle(query.Album)
	normCandidate := m.norm.NormalizeTitle(candidate.Album)

	if normQuery == normCandidate {
		return 1.0
	}

	return m.norm.Similarity(normQuery, normCandidate)
}

func (m *Matcher) scoreDuration(query TrackQuery, candidate TrackCandidate) float64 {
	if query.Duration <= 0 || candidate.Duration <= 0 {
		return 0.5
	}

	diff := abs(query.Duration - candidate.Duration)
	if diff <= m.config.DurationToleranceMs {
		return 1.0 - (float64(diff) / float64(m.config.DurationToleranceMs)) * 0.3
	}

	if diff > 30000 {
		return 0.1
	}

	return 0.5
}

func (m *Matcher) scoreISRC(query TrackQuery, candidate TrackCandidate) float64 {
	if query.ISRC == "" || candidate.ISRC == "" {
		return 0.5
	}

	if strings.EqualFold(query.ISRC, candidate.ISRC) {
		return 1.0
	}

	return 0
}

func (m *Matcher) generateReasons(query TrackQuery, candidate TrackCandidate, breakdown ScoreBreakdown) []string {
	var reasons []string

	if breakdown.TitleScore >= 0.95 {
		reasons = append(reasons, "exact_title")
	} else if breakdown.TitleScore >= 0.8 {
		reasons = append(reasons, "fuzzy_title")
	}

	if breakdown.ArtistScore >= 0.95 {
		reasons = append(reasons, "exact_artist")
	} else if breakdown.ArtistScore >= 0.8 {
		reasons = append(reasons, "fuzzy_artist")
	}

	if breakdown.AlbumScore >= 0.9 {
		reasons = append(reasons, "album_match")
	}

	if breakdown.DurationScore >= 0.9 {
		reasons = append(reasons, "duration_match")
	}

	if breakdown.ISRCScore >= 1.0 {
		reasons = append(reasons, "isrc_match")
	}

	return reasons
}

func (m *Matcher) Similarity(a, b string) float64 {
	return m.norm.Similarity(a, b)
}

type Normalizer struct {
	accentMap map[rune]rune
}

func NewNormalizer() *Normalizer {
	n := &Normalizer{
		accentMap: make(map[rune]rune),
	}
	n.initAccentMap()
	return n
}

func (n *Normalizer) initAccentMap() {
	accentPairs := map[string]string{
		"ÀÁÂÃÄÅàáâãäå": "AAAAAAaaaaaa",
		"ÒÓÔÕÖØòóôõöø": "OOOOOOoooooo",
		"ÈÉÊËèéêë":     "EEEEeeee",
		"Çç":           "Cc",
		"ÌÍÎÏìíîï":     "IIIIiiii",
		"ÙÚÛÜùúûü":     "UUUUuuuu",
		"ÿ":            "y",
		"Ññ":           "Nn",
		"Šš":           "Ss",
		"Žž":           "Zz",
		"Ðð":           "Dd",
		"Þþ":           "THth",
		"Ææ":           "AEae",
		"Œœ":           "OEoe",
	}

	for accented, plain := range accentPairs {
		for i, r := range accented {
			n.accentMap[r] = rune(plain[i])
		}
	}
}

func (n *Normalizer) removeAccents(s string) string {
	result := make([]rune, 0, len(s))
	for _, r := range s {
		if replacement, ok := n.accentMap[r]; ok {
			result = append(result, replacement)
		} else {
			result = append(result, r)
		}
	}
	return string(result)
}

func (n *Normalizer) NormalizeTitle(title string) string {
	s := n.removeAccents(title)
	s = strings.ToLower(s)

	patterns := []*regexp.Regexp{
		regexp.MustCompile(`[\(\[].*?(feat\.|ft\.|featuring).*?[\)\]]`, regexp.IGNORECASE),
		regexp.MustCompile(`-\s*(feat\.|ft\.|featuring).*`, regexp.IGNORECASE),
		regexp.MustCompile(`[^\w\s]`),
		regexp.MustCompile(`\s+`),
	}

	for _, re := range patterns {
		s = re.ReplaceAllString(s, " ")
	}

	return strings.TrimSpace(s)
}

func (n *Normalizer) NormalizeArtist(artist string) string {
	s := n.removeAccents(artist)
	s = strings.ToLower(s)

	patterns := []*regexp.Regexp{
		regexp.MustCompile(`[\(\[].*?(feat\.|ft\.|featuring).*?[\)\]]`, regexp.IGNORECASE),
		regexp.MustCompile(`-\s*(feat\.|ft\.|featuring).*`, regexp.IGNORECASE),
		regexp.MustCompile(`\s*&\s*`, " and "),
		regexp.MustCompile(`\s*,\s*`, " and "),
		regexp.MustCompile(`\s*x\s*`, " and "),
		regexp.MustCompile(`\b(topic|vevo|official)\b`, ""),
		regexp.MustCompile(`-?\s*topic\s*songs?`, ""),
		regexp.MustCompile(`[^\w\s]`),
		regexp.MustCompile(`\s+`),
	}

	for _, re := range patterns {
		s = re.ReplaceAllString(s, " ")
	}

	return strings.TrimSpace(s)
}

func (n *Normalizer) NormalizeAlbum(album string) string {
	return n.NormalizeTitle(album)
}

func (n *Normalizer) Similarity(a, b string) float64 {
	if a == b {
		return 1.0
	}
	if a == "" || b == "" {
		return 0.0
	}

	return jaroWinkler(a, b)
}

func jaroWinkler(s1, s2 string) float64 {
	if s1 == s2 {
		return 1.0
	}
	if len(s1) == 0 || len(s2) == 0 {
		return 0.0
	}

	matchWindow := max(len(s1), len(s2))/2 - 1
	if matchWindow < 1 {
		matchWindow = 1
	}

	s1Matches := make([]bool, len(s1))
	s2Matches := make([]bool, len(s2))

	matches := 0
	transpositions := 0

	for i := 0; i < len(s1); i++ {
		start := max(0, i-matchWindow)
		end := min(len(s2), i+matchWindow+1)

		for j := start; j < end; j++ {
			if s2Matches[j] {
				continue
			}
			if rune(s1[i]) != rune(s2[j]) {
				continue
			}
			s1Matches[i] = true
			s2Matches[j] = true
			matches++
			break
		}
	}

	if matches == 0 {
		return 0.0
	}

	k := 0
	for i := 0; i < len(s1); i++ {
		if !s1Matches[i] {
			continue
		}
		for k < len(s2) && !s2Matches[k] {
			k++
		}
		if k < len(s2) && rune(s1[i]) != rune(s2[k]) {
			transpositions++
		}
		k++
	}

	m := float64(matches)
	jaro := (m/float64(len(s1)) + m/float64(len(s2)) + (m-float64(transpositions)/2)/m) / 3.0

	prefix := 0
	prefixLimit := min(4, min(len(s1), len(s2)))
	for i := 0; i < prefixLimit; i++ {
		if s1[i] == s2[i] {
			prefix++
		} else {
			break
		}
	}

	return jaro + (float64(prefix) * 0.1 * (1 - jaro))
}

type TrackQuery struct {
	Title   string
	Artist  string
	Album   string
	Duration int64
	ISRC    string
}

type TrackCandidate struct {
	ID       string
	Title    string
	Artist   string
	Album    string
	Duration int64
	ISRC     string
	Source   string
}

func abs(a int64) int64 {
	if a < 0 {
		return -a
	}
	return a
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

type Scorer interface {
	Score(query TrackQuery, candidate TrackCandidate) float64
}

type CompositeScorer struct {
	scorers []Scorer
	weights []float64
}

func NewCompositeScorer(scorers []Scorer, weights []float64) *CompositeScorer {
	if len(scorers) != len(weights) {
		weights = make([]float64, len(scorers))
		for i := range weights {
			weights[i] = 1.0 / float64(len(scorers))
		}
	}
	return &CompositeScorer{
		scorers: scorers,
		weights: weights,
	}
}

func (c *CompositeScorer) Score(query TrackQuery, candidate TrackCandidate) float64 {
	var total float64
	for i, scorer := range c.scorers {
		total += scorer.Score(query, candidate) * c.weights[i]
	}
	return total
}

type TitleScorer struct{}

func (TitleScorer) Score(query TrackQuery, candidate TrackCandidate) float64 {
	if query.Title == "" || candidate.Title == "" {
		return 0
	}
	return jaroWinkler(
		strings.ToLower(query.Title),
		strings.ToLower(candidate.Title),
	)
}

type ArtistScorer struct{}

func (ArtistScorer) Score(query TrackQuery, candidate TrackCandidate) float64 {
	if query.Artist == "" || candidate.Artist == "" {
		return 0
	}
	return jaroWinkler(
		strings.ToLower(query.Artist),
		strings.ToLower(candidate.Artist),
	)
}

type DurationScorer struct {
	ToleranceMs int64
}

func (d DurationScorer) Score(query TrackQuery, candidate TrackCandidate) float64 {
	if query.Duration <= 0 || candidate.Duration <= 0 {
		return 0.5
	}
	diff := abs(query.Duration - candidate.Duration)
	if diff <= d.ToleranceMs {
		return 1.0 - (float64(diff)/float64(d.ToleranceMs))*0.3
	}
	if diff > 30000 {
		return 0.1
	}
	return 0.5
}

type ISRCScorer struct{}

func (ISRCScorer) Score(query TrackQuery, candidate TrackCandidate) float64 {
	if query.ISRC == "" || candidate.ISRC == "" {
		return 0.5
	}
	if strings.EqualFold(query.ISRC, candidate.ISRC) {
		return 1.0
	}
	return 0
}