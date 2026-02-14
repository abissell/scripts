#!/bin/sh

# apply-configs-updates.sh: copies relevant config files into place
# Copyright (C) 2023  Andrew Bissell

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

. ./common.sh

ensure_working_directory "$HOME"

cd configs && git pull && cd ..

cp configs/.aliases ../
mkdir -p .local/share/eclipse && cp configs/java/eclipse-java-google-style-4-spaces.xml .local/share/eclipse

if [ $(uname) = "FreeBSD" ]; then
  cp freebsd/.aliases_freebsd ../
fi
