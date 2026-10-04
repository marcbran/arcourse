package jsonfile

import (
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"io"
	"os"
	"path/filepath"

	"github.com/marcbran/arcourse/internal/course"
)

type BlobStore struct {
	dir string
}

func NewBlobStore(dir string) *BlobStore {
	return &BlobStore{dir: dir}
}

func (s *BlobStore) Put(ctx context.Context, content string) (course.ContentID, error) {
	err := ctx.Err()
	if err != nil {
		return "", err
	}
	sum := sha256.Sum256([]byte(content))
	id := course.ContentID(hex.EncodeToString(sum[:]))
	path := s.blobPath(id)
	_, err = os.Stat(path)
	if err == nil {
		return id, nil
	}
	if !os.IsNotExist(err) {
		return "", err
	}
	err = os.MkdirAll(filepath.Dir(path), 0o755)
	if err != nil {
		return "", err
	}
	temp, err := os.CreateTemp(filepath.Dir(path), ".blob-*")
	if err != nil {
		return "", err
	}
	defer func() {
		_ = os.Remove(temp.Name())
	}()
	writer := gzip.NewWriter(temp)
	_, err = io.WriteString(writer, content)
	if err != nil {
		_ = temp.Close()
		return "", err
	}
	err = writer.Close()
	if err != nil {
		_ = temp.Close()
		return "", err
	}
	err = temp.Close()
	if err != nil {
		return "", err
	}
	err = os.Rename(temp.Name(), path)
	if err != nil {
		return "", err
	}
	return id, nil
}

func (s *BlobStore) Get(ctx context.Context, contentID course.ContentID) (string, error) {
	err := ctx.Err()
	if err != nil {
		return "", err
	}
	file, err := os.Open(s.blobPath(contentID))
	if err != nil {
		return "", err
	}
	defer func() {
		_ = file.Close()
	}()
	reader, err := gzip.NewReader(file)
	if err != nil {
		return "", err
	}
	defer func() {
		_ = reader.Close()
	}()
	content, err := io.ReadAll(reader)
	if err != nil {
		return "", err
	}
	return string(content), nil
}

func (s *BlobStore) blobPath(contentID course.ContentID) string {
	id := string(contentID)
	if len(id) < 2 {
		return filepath.Join(s.dir, "blobs", id+".gz")
	}
	return filepath.Join(s.dir, "blobs", id[:2], id+".gz")
}
