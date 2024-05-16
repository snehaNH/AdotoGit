#!/bin/bash

# Azure DevOps credentials
AZURE_ORG="hegadenaveen"
AZURE_PROJECT="Test"
AZURE_TOKEN="$Ado-Token"

# GitHub credentials
GITHUB_USERNAME="Git-Uname"
GITHUB_TOKEN="Git-Token"

# Directory to store backup
BACKUP_DIR="./azure_repos_backup"

# Function to clone repository from Azure DevOps
clone_ado_repo() {
    local repo_name="$1"
    local repo_url="https://dev.azure.com/$AZURE_ORG/$AZURE_PROJECT/_git/$repo_name"
    echo "Cloning repository $repo_name from Azure DevOps..."
    git clone "$repo_url" "$BACKUP_DIR/$repo_name"
    echo "Repository $repo_name cloned from Azure DevOps."
}

# Function to clone repository from GitHub
clone_github_repo() {
    local repo_name="$1"
    local repo_url="https://github.com/$GITHUB_USERNAME/$repo_name.git"
    echo "Cloning repository $repo_name from GitHub..."
    git clone "$repo_url" "$BACKUP_DIR/$repo_name"_github
    echo "Repository $repo_name cloned from GitHub."
}

# Function to merge repositories
merge_repos() {
    local repo_name="$1"
    echo "Merging repositories for $repo_name..."
    # Remove .git directory from GitHub repository clone
    rm -rf "$BACKUP_DIR/$repo_name"_github/.git
    # Merge contents
    cp -r "$BACKUP_DIR/$repo_name"_github/. "$BACKUP_DIR/$repo_name"
    echo "Repositories merged successfully for $repo_name."
}

# Function to initialize Git and push to GitHub
initialize_and_push() {
    local repo_name="$1"
    echo "Initializing Git and pushing to GitHub for $repo_name..."
    # Change directory to the repository
    cd "$BACKUP_DIR/$repo_name" || exit
    # Initialize new Git repository
    git init
    git add .
    git commit -m "Merged Azure DevOps and GitHub repositories"
    # Ensure we are not setting remote origin to Azure DevOps
    git remote remove origin
    git remote add origin "https://github.com/$GITHUB_USERNAME/$repo_name.git"
    # Pull changes from GitHub
    git pull origin master
    # Push changes to GitHub
    git push -u origin master
    echo "Changes pushed to GitHub repository $repo_name."
}


# Function to create repository on GitHub
create_github_repo() {
    local repo_name="$1"
    echo "Creating repository $repo_name on GitHub..."
    curl -X POST -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/user/repos" -d "{\"name\":\"$repo_name\"}"
    echo "Repository $repo_name created on GitHub."
}

# Function to backup Azure DevOps repositories
backup_azure_repos() {
    echo "Backing up Azure DevOps repositories..."
    if [ -d "$BACKUP_DIR" ]; then
        echo "Removing existing backup directory..."
        rm -rf "$BACKUP_DIR"
    fi
    mkdir -p "$BACKUP_DIR"
    # Loop through each Azure DevOps repository
    AZURE_DEVOPS_EXT_PAT="$AZURE_TOKEN" az repos list --org "https://dev.azure.com/$AZURE_ORG" --project "$AZURE_PROJECT" --output tsv --query '[].{Name:name, URL:url}' | while IFS=$'\t' read -r name url; do
        if ! curl --silent --head "https://github.com/$GITHUB_USERNAME/$name" | head -n 1 | grep "HTTP/.* 200"; then
            create_github_repo "$name"
        fi
        clone_github_repo "$name"
        clone_ado_repo "$name"
        merge_repos "$name"
        initialize_and_push "$name"
    done
    echo "Backup and merge complete."
}

# Main function
main() {
    backup_azure_repos
}

# Call the main function
main