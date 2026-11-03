#!/bin/sh
# Let Umbriel end the current compositor session. Do not kill unrelated app processes.
exec umbriel msg session-quit skip-confirmation
