local namespace = {
  namespace: '$namespace',
};

{
  namespaces: {
    all: {
      _paths: [
        'namespace("default")'
      ],
    },
  },
  namespace(namespace):: namespace {
    namespace: namespace,
  },
}
