# frozen_string_literal: true

# Copyright 2025 Daytona Platforms Inc.
# SPDX-License-Identifier: Apache-2.0

module Daytona
  module Services
    # Git operations for Sandbox
    #
    # Provides methods for Git repository management within the Sandbox.
    #
    # @example
    #   # Clone a repository
    #   sandbox.git.clone("https://github.com/user/repo.git", "/home/user/repo")
    #
    #   # Create and commit
    #   sandbox.git.add("/home/user/repo", ["file.txt"])
    #   sandbox.git.commit("/home/user/repo", "Add file", "User", "user@example.com")
    class Git < BaseService
      # Stage files for commit
      #
      # @param path [String] Repository path
      # @param files [Array<String>] Files to stage
      #
      # @example
      #   sandbox.git.add("/home/user/repo", ["file1.txt", "file2.txt"])
      def add(path, files)
        toolbox_post("/git/add", body: { path: path, files: files })
      end

      # List branches
      #
      # @param path [String] Repository path
      # @return [Array<Hash>] List of branches with name and current flag
      #
      # @example
      #   branches = sandbox.git.branches("/home/user/repo")
      #   branches.each { |b| puts b['name'] }
      def branches(path)
        response = toolbox_get("/git/branches", params: { path: path })
        response["branches"] || response[:branches] || []
      end

      # Clone a repository
      #
      # @param url [String] Repository URL
      # @param path [String] Destination path
      # @param branch [String, nil] Branch to clone
      # @param commit_id [String, nil] Specific commit to checkout
      # @param username [String, nil] Git username for authentication
      # @param password [String, nil] Git password/token for authentication
      #
      # @example
      #   sandbox.git.clone("https://github.com/user/repo.git", "/home/user/repo")
      #   sandbox.git.clone("https://github.com/user/private.git", "/home/user/private",
      #                     username: "user", password: "token")
      def clone(url, path, branch: nil, commit_id: nil, username: nil, password: nil)
        body = { url: url, path: path }
        body[:branch] = branch if branch
        body[:commitId] = commit_id if commit_id
        body[:username] = username if username
        body[:password] = password if password

        toolbox_post("/git/clone", body: body)
      end

      # Create a commit
      #
      # @param path [String] Repository path
      # @param message [String] Commit message
      # @param author [String] Author name
      # @param email [String] Author email
      # @param allow_empty [Boolean] Allow empty commits
      #
      # @example
      #   sandbox.git.commit("/home/user/repo", "Fix bug", "User", "user@example.com")
      def commit(path, message, author, email, allow_empty: false)
        toolbox_post("/git/commit", body: {
          path: path,
          message: message,
          author: author,
          email: email,
          allowEmpty: allow_empty,
        })
      end

      # Initialize a new repository
      #
      # @param path [String] Repository path
      #
      # @example
      #   sandbox.git.init("/home/user/new_repo")
      def init(path)
        toolbox_post("/git/init", body: { path: path })
      end

      # Push changes to remote
      #
      # @param path [String] Repository path
      # @param username [String, nil] Git username
      # @param password [String, nil] Git password/token
      #
      # @example
      #   sandbox.git.push("/home/user/repo", username: "user", password: "token")
      def push(path, username: nil, password: nil)
        body = { path: path }
        body[:username] = username if username
        body[:password] = password if password

        toolbox_post("/git/push", body: body)
      end

      # Pull changes from remote
      #
      # @param path [String] Repository path
      # @param username [String, nil] Git username
      # @param password [String, nil] Git password/token
      #
      # @example
      #   sandbox.git.pull("/home/user/repo")
      def pull(path, username: nil, password: nil)
        body = { path: path }
        body[:username] = username if username
        body[:password] = password if password

        toolbox_post("/git/pull", body: body)
      end

      # Get repository status
      #
      # @param path [String] Repository path
      # @return [Hash] Status with staged, unstaged, and untracked files
      #
      # @example
      #   status = sandbox.git.status("/home/user/repo")
      #   puts "Modified: #{status['unstaged']}"
      def status(path)
        toolbox_get("/git/status", params: { path: path })
      end

      # Checkout a branch
      #
      # @param path [String] Repository path
      # @param branch [String] Branch name
      #
      # @example
      #   sandbox.git.checkout_branch("/home/user/repo", "feature-branch")
      def checkout_branch(path, branch)
        toolbox_post("/git/checkout", body: { path: path, branch: branch })
      end

      # Create a new branch
      #
      # @param path [String] Repository path
      # @param name [String] New branch name
      #
      # @example
      #   sandbox.git.create_branch("/home/user/repo", "new-feature")
      def create_branch(path, name)
        toolbox_post("/git/branch/create", body: { path: path, name: name })
      end

      # Delete a branch
      #
      # @param path [String] Repository path
      # @param name [String] Branch name to delete
      #
      # @example
      #   sandbox.git.delete_branch("/home/user/repo", "old-feature")
      def delete_branch(path, name)
        toolbox_post("/git/branch/delete", body: { path: path, name: name })
      end

      # Unstage files
      #
      # @param path [String] Repository path
      # @param files [Array<String>] Files to unstage
      #
      # @example
      #   sandbox.git.remove("/home/user/repo", ["file.txt"])
      def remove(path, files)
        toolbox_post("/git/reset", body: { path: path, files: files })
      end

      # Get commit log
      #
      # @param path [String] Repository path
      # @param limit [Integer] Maximum number of commits to return
      # @return [Array<Hash>] List of commits
      #
      # @example
      #   commits = sandbox.git.log("/home/user/repo", limit: 10)
      #   commits.each { |c| puts c['message'] }
      def log(path, limit: 20)
        response = toolbox_get("/git/log", params: { path: path, limit: limit })
        response["commits"] || response[:commits] || []
      end
    end
  end
end
