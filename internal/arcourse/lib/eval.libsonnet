local truncateNode = import 'truncate_node.libsonnet';

function(root, value) truncateNode(value, 'eval')
