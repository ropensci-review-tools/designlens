#!/bin/bash

# Show current project state
# Determines what should be done next

# Source colors and logo
lib_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$lib_dir/colors.sh"
source "$lib_dir/logo.sh"
source "$lib_dir/commits-since-stage.sh"

spec_status() {
  show_logo

  if [ ! -d specs ]; then
    error "/specs directory not found. Run 'designlens init' first."
    exit 1
  fi

  heading "designlens status"
  echo ""

  # Find all stages
  local stages=()
  for dir in specs/[0-9][0-9][0-9]-*; do
    if [ -d "$dir" ]; then
      stages+=("$dir")
    fi
  done

  if [ ${#stages[@]} -eq 0 ]; then
    info "No stages found."
    echo ""
    prompt "Next action: run /designlens.new-stage to plan and create the first stage"
    return
  fi

  # Get the latest stage (portable to bash 3.2: no negative index)
  local latest_stage="${stages[${#stages[@]} - 1]}"
  local stage_name
  stage_name=$(basename "$latest_stage")

  echo "Current stage: $stage_name"
  echo ""

  # Check file status
  local plan_exists=false
  local tasks_exists=false
  local decisions_exists=false
  local tasks_complete=false

  [ -f "$latest_stage/plan.md" ] && plan_exists=true
  [ -f "$latest_stage/tasks.md" ] && tasks_exists=true
  [ -f "$latest_stage/design-decisions.md" ] && decisions_exists=true

  # Check task completion
  if [ "$tasks_exists" = true ]; then
    local total_tasks completed_tasks
    total_tasks=$(grep -c "^\- \[" "$latest_stage/tasks.md" 2>/dev/null || echo 0)
    completed_tasks=$(grep -c "^\- \[x\]" "$latest_stage/tasks.md" 2>/dev/null || echo 0)

    if [ "$total_tasks" -gt 0 ]; then
      echo "Tasks: $completed_tasks/$total_tasks complete"
      if [ "$completed_tasks" -eq "$total_tasks" ] && [ "$total_tasks" -gt 0 ]; then
        tasks_complete=true
      fi
    fi
  fi

  echo ""

  # Determine next action
  if [ "$plan_exists" = false ]; then
    prompt "Next action: run /designlens.new-stage — plan.md is missing from $latest_stage"
    return
  fi

  if [ "$tasks_exists" = false ]; then
    prompt "Next action: run /designlens.make-tasks to generate tasks.md from plan.md"
    return
  fi

  if [ "$tasks_complete" = false ]; then
    prompt "Next action: run /designlens.implement to execute remaining tasks"
    return
  fi

  if [ "$decisions_exists" = false ]; then
    # Skip the retrospective recommendation for brand-new repos: with fewer
    # than `threshold` commits total, there isn't enough history yet for a
    # meaningful retrospective, so always and entirely skip it.
    local csr_output total_commits threshold
    csr_output=$(commits_since_stage 2>/dev/null) || true
    total_commits=$(echo "$csr_output" | grep '^total_commits=' | cut -d= -f2)
    threshold=$(echo "$csr_output" | grep '^threshold=' | cut -d= -f2)

    if [ -n "$total_commits" ] && [ -n "$threshold" ] && [ "$total_commits" -lt "$threshold" ]; then
      success "Stage complete! (retrospective skipped — only $total_commits commit(s) so far, fewer than the threshold of $threshold)"
      echo ""
      prompt "Next action: run /designlens.new-stage to begin the next stage"
      return
    fi

    prompt "Next action: run /designlens.retrospective to generate design decisions"
    return
  fi

  # All complete
  success "Stage complete!"
  echo ""
  prompt "Next action: run /designlens.new-stage to begin the next stage"
}
