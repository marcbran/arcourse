package course

import (
	"context"
)

type Facade struct {
	recordVisit          *recordVisit
	listSessions         *ListSessions
	getSession           *GetSession
	getVisit             *GetVisit
	getEvaluationContent *getEvaluationContent
	repo                 Repo
}

func NewFacade(repo Repo, blobs BlobStore) *Facade {
	return &Facade{
		recordVisit:          newRecordVisit(repo, blobs, nil),
		listSessions:         NewListSessions(repo),
		getSession:           NewGetSession(repo),
		getVisit:             NewGetVisit(repo),
		getEvaluationContent: newGetEvaluationContent(blobs),
		repo:                 repo,
	}
}

func (f *Facade) Observe(observer Observer) {
	f.recordVisit.observer = observer
}

func (f *Facade) Record(ctx context.Context, ref VisitRef, evaluationID EvaluationID, address Address, contents map[Projection]string, origin Origin) VisitRef {
	return f.recordVisit.Exec(ctx, ref, evaluationID, address, contents, origin)
}

func (f *Facade) Sessions(ctx context.Context) ([]SessionSummary, error) {
	return f.listSessions.Exec(ctx)
}

func (f *Facade) Session(ctx context.Context, sessionID SessionID) (Session, error) {
	return f.getSession.Exec(ctx, sessionID)
}

func (f *Facade) Visit(ctx context.Context, visitID VisitID) (Visit, error) {
	return f.getVisit.Exec(ctx, visitID)
}

func (f *Facade) Evaluation(ctx context.Context, evaluationID EvaluationID) (Event, error) {
	return f.repo.Get(ctx, evaluationID)
}

func (f *Facade) Content(ctx context.Context, event Event, projection Projection) (string, error) {
	return f.getEvaluationContent.Exec(ctx, event, projection)
}
