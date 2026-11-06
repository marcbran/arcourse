local page = import 'arcourse-ui/page.libsonnet';
local failureCard = import 'arcourse-ui/failure.libsonnet';

function(failure, format)
  if format == 'html' then std.native('invoke:html')('manifestHtml', [page { fragment:: failureCard { failure:: failure } }])
  else if format == 'json' then std.manifestJsonEx({ _failure: failure }, '   ')
  else ''
