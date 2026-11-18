#!/usr/bin/env bash

set -euo pipefail
bundle exec rails db:prepare feature_flags:initialize
