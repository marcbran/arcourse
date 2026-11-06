local isFailure(value) = std.isObject(value) && std.objectHas(value, '_failure');

{
  isFailure: isFailure,
  withFailure: {
    _failure:: if isFailure(std.get(self, 'response')) then self.response._failure else null,
  },
}
