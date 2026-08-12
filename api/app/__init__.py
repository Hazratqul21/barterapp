"""BarterApp server.

The version check below is the first thing that runs in the package, and it is
here because of what happens without it.

macOS ships Python 3.9 as `python3`, so the README's `python3 -m venv .venv`
builds a 3.9 environment on a machine that also has 3.12 installed. Everything
then installs cleanly and the server dies on the first import with

    ImportError: cannot import name 'UTC' from 'datetime'

which says nothing about the actual problem. `datetime.UTC` arrived in 3.11 and
the server uses it wherever it stamps a time, so 3.11 is a hard floor rather
than a preference.
"""

import sys

_MINIMUM = (3, 11)

if sys.version_info < _MINIMUM:
    raise RuntimeError(
        "BarterApp serveri Python {}.{}+ talab qiladi, hozirgisi {}.{}.\n"
        "\n"
        "macOS'dagi `python3` — bu 3.9. Muhitni aniq versiya bilan quring:\n"
        "\n"
        "    python3.12 -m venv .venv\n"
        "    .venv/bin/pip install -r requirements.txt\n"
        "\n"
        "Mavjud versiyalarni ko'rish: `ls /usr/local/bin/python3.* "
        "/opt/homebrew/bin/python3.*`".format(
            _MINIMUM[0],
            _MINIMUM[1],
            sys.version_info.major,
            sys.version_info.minor,
        )
    )
