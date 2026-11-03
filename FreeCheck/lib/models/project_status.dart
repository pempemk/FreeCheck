/// Status of a project. [value] is what the database stores.
enum ProjectStatus {
  inProgress('in_progress'),
  pending('pending'),
  submitted('submitted'),
  completed('completed');

  const ProjectStatus(this.value);

  final String value;
}
