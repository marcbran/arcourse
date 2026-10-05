package arcourse

import "path/filepath"

const (
	stateDirName  = ".arcourse"
	cacheDirName  = "cache"
	courseDirName = "course"
)

func CacheDir(rootDir string) string {
	return filepath.Join(rootDir, stateDirName, cacheDirName)
}

func CourseDir(rootDir string) string {
	return filepath.Join(rootDir, stateDirName, courseDirName)
}
