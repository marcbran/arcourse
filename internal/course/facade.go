package course

import (
	"context"
)

type Facade struct {
	recordVisit          *recordVisit
	startExecution       *startExecution
	finishExecution      *finishExecution
	recordRemark         *recordRemark
	listSessions         *ListSessions
	getSession           *GetSession
	getVisit             *GetVisit
	getEvaluationContent *getEvaluationContent
	getExecutionOutput   *getExecutionOutput
	repo                 Repo
}

func NewFacade(repo Repo, blobs BlobStore) *Facade {
	return &Facade{
		recordVisit:          newRecordVisit(repo, blobs),
		startExecution:       newStartExecution(repo),
		finishExecution:      newFinishExecution(repo, blobs),
		recordRemark:         newRecordRemark(repo),
		listSessions:         NewListSessions(repo),
		getSession:           NewGetSession(repo),
		getVisit:             NewGetVisit(repo),
		getEvaluationContent: newGetEvaluationContent(blobs),
		getExecutionOutput:   newGetExecutionOutput(blobs),
		repo:                 repo,
	}
}

func (f *Facade) Observe(observer Observer) {
	f.recordVisit.observer = observer
	f.startExecution.observer = observer
	f.finishExecution.observer = observer
	f.recordRemark.observer = observer
}

func (f *Facade) Record(ctx context.Context, ref VisitRef, evaluationID EvaluationID, address Address, contents map[Projection]string, origin Origin) VisitRef {
	return f.recordVisit.Exec(ctx, ref, evaluationID, address, contents, origin)
}

func (f *Facade) StartExecution(ctx context.Context, from Evaluation) (Execution, error) {
	return f.startExecution.Exec(ctx, from)
}

func (f *Facade) FinishExecution(ctx context.Context, execution Execution, output string, failure error) error {
	return f.finishExecution.Exec(ctx, execution, output, failure)
}

func (f *Facade) Remark(ctx context.Context, from EvaluationID, text string) (RemarkID, error) {
	return f.recordRemark.Exec(ctx, from, text)
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

func (f *Facade) Evaluation(ctx context.Context, evaluationID EvaluationID) (Evaluation, error) {
	return f.repo.Evaluation(ctx, evaluationID)
}

func (f *Facade) Execution(ctx context.Context, executionID ExecutionID) (Execution, error) {
	return f.repo.Execution(ctx, executionID)
}

func (f *Facade) Content(ctx context.Context, evaluation Evaluation, projection Projection) (string, error) {
	return f.getEvaluationContent.Exec(ctx, evaluation, projection)
}

func (f *Facade) Output(ctx context.Context, execution Execution) (string, error) {
	return f.getExecutionOutput.Exec(ctx, execution)
}
