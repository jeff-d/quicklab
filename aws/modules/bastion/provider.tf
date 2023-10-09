# This file is part of QuickLab, which creates simple, monitored labs.
# https://github.com/jeff-d/quicklab
#
# SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later


terraform {
  required_providers {
    sumologic = {
      source  = "SumoLogic/sumologic"
      version = "~> 2.22"
    }
  }
}
