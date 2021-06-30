<#
.SYNOPSIS
Squash all changes made in a branch down to a single commit

.DESCRIPTION
This script will squash all of your changes down to a single commit.
It is similar to doing a rebase, but has the added benefit that you won't have to re-resolve merge conflicts if you have already merged from the target branch.

.PARAMETER TargetMergeBranch
The branch that you plan on merging this branch into

.PARAMETER CreateBackupBranch
Indicates if a backup of the current branch should be made before starting

.PARAMETER ForcePush
Indicates if origin should be updated if we find no diffences between the branch and origin version after squash completes

.PARAMETER SetNotepadEditor
Indicates if you would like to use notepad as your git editor instead of the default VI

.EXAMPLE
.\SquashGitBranch.ps1 -TargetMergeBranch master -CreateBackupBranch $true -ForcePush $false -SetNotepadEditor $true

#>
Param (
    [string] $TargetMergeBranch = "master",
    [bool] $CreateBackupBranch = $true,
    [bool] $ForcePush = $true,
    [bool] $SetNotepadEditor = $true
)
$ErrorActionPreference = "Stop"

if ($SetNotepadEditor) {
    $editor = git config core.editor
    if ($editor) {
        Write-Host "Editor already set to $editor"
    }
    else {
        Write-Host "Setting notepad to default Git Editor"
        git config core.editor notepad
    }
}

$branch = git rev-parse --abbrev-ref HEAD
$tempBranch = "temp/$($branch)"

if ($CreateBackupBranch) {
    $backup = "backup/$($branch)"
    Write-Host "Creating backup of current branch: $($backup)"
    if (git branch | Select-String $backup) {
        git branch -D $backup
    }
    git checkout -b $backup $branch
}

Write-Host "Updating local repo from origin with 'git fetch --prune'"
git fetch --prune

Write-Host "Switching to $($TargetMergeBranch) and updating with origin"
git checkout $TargetMergeBranch
git pull

Write-Host "Updating $($branch) with merge from $($TargetMergeBranch)"
git checkout $branch
git merge $TargetMergeBranch

Write-Host "Creating temp branch of $($TargetMergeBranch) to squash merge with"
git checkout -b $tempBranch $TargetMergeBranch

Write-Host "squash merging $($branch) into temp branch"
git merge --no-commit --squash $branch

Write-Host "Commiting squash merge"
git commit

Write-Host "Returning back to branch: $($branch)"
git checkout $branch

Write-Host "Performing diff between temp branch and current branch to ensure no changes were made."
$diff = git diff $tempBranch..$branch
if ($diff) {
    throw "Squash merge with $($TargetMergeBranch) will result in differences. Ensure source branch is merged with $($TargetMergeBranch)."
}

Write-Host "Reseting branch to squash merged temp branch."
git reset --hard $tempBranch

Write-Host "Deleting temp branch"
git branch -d $tempBranch

if ($ForcePush) {
    $diff = git diff "origin/$($branch)"..$branch
    if ($diff) {
        throw "current branch and origin are not equivalent."
    }

    git push --force
}
