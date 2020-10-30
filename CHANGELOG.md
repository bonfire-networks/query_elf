# Changelog

## v0.3.0

**Important**: This release contains a breaking change, as pagination is no longer included by default in every query builder. To retain the old behaviour you should use the `QueryElf.Plugins.OffsetPagination` plugin (check the [docs](https://hexdocs.pm/query_elf) for more details).

### Enhancements

- The plugin interface has been streamlined, making the code for the main `QueryElf` module simpler and more extendable.
- Automatic filter and sorter definition were moved to their own independent plugins (the `searchable_fields` and `sortable_fields` were kept as a shorthand to use the plugins and also for compatibility reasons).
