If you get a line ending issue with '$\r': command not found errors, try these fixes:

	fix-config.bat          - Quick PowerShell fix for config.sh only
	fix-line-endings.bat    - Comprehensive fix for all files
	
These scripts automatically navigate to the root directory and fix line endings.

Alternatively, use this WSL command directly:
	sed -i 's/\r$//' config.sh

This issue occurs when Windows saves files with CRLF line endings,
but bash expects LF line endings. Any of these methods will fix it.