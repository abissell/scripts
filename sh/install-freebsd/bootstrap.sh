#!/bin/sh

# FreeBSD installation bootstrap.sh
# Copyright (C) 2023 Andrew Bissell
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

. ./common.sh
ensure_working_directory "/usr/home/$(logname)"
ensure_root

echo
echo "Pinging pkg.freebsd.org"
ping -c 1 pkg.freebsd.org
echo "Updating pkg ..."
pkg update -f
echo "... updating pkg succeeded."
echo
echo "Installing sudo ..."
pkg install sudo
echo "... installing sudo succeeded."
echo
echo "While still root, run 'visudo'"
echo "and uncomment the line:"
echo "# %wheel ALL=(ALL) ALL"
echo
echo "Once done, initial bootstrap is complete!"
echo
