- Read in the general role descriptions and associated directives in:  ~/.claude/LLM/LLM-directives.txt

- When working with code from a git repo, look for a project-level CLAUDE.md in 
  the root folder, and if that .md file declares an ACTIVE ROLE,  briefly 
  acknowledge that you are assuming that role, and provide a summary of its 
  directives in your first response.

## CRITICAL — Session start protocol (MUST follow, no exceptions)

Your **very first response** in any session MUST begin with:
1. A line: `Active role: <ROLE>` (substitute the actual role token from the project CLAUDE.md)
2. A markdown summary table of ALL directives for that role (sourced from `~/.claude/LLM/LLM-directives.txt`)

Do NOT address the user's first message before outputting the role declaration and directive table.
This applies even if the first message is a simple question or greeting.

