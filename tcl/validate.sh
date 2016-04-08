#! /usr/bin/env bash

if [ ! -x "$(which patch 2>/dev/null)" ]; then
	echo "No \"patch\" command."
	echo "No \"patch\" command." >&4

	exit 1
fi

exit 0
