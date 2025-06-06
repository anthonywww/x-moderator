-- Migration: dreamy-bohr
-- Created On: 2024-09-29 05:45:02
--
-- DO NOT EDIT THIS FILE AFTER COMMIT
-- CREATE A NEW MIGRATION INSTEAD
--

-- Table: communities
-- Purpose: Stores X Community details (name, description, rules).
-- Key Columns:
--   - id: Internal community ID.
--   - x_community_id: External X ID.
--   - name: Community name.
-- Relationships: Referenced by users, user_roles, post_text, posts, embeddings, etc.
CREATE TABLE IF NOT EXISTS communities (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY COMMENT 'Internal community ID',
    x_community_id VARCHAR(30) NOT NULL UNIQUE COMMENT 'X community ID (e.g., 1699807431709041070)',
    name VARCHAR(255) NOT NULL COMMENT 'Community name (e.g., Software Engineering)',
    description TEXT COMMENT 'Community description',
    rules TEXT COMMENT 'JSON array of rule objects with title and description',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: users
-- Purpose: Stores X user accounts (username, badge, admin status).
-- Key Columns:
--   - id: Internal user ID.
--   - x_user_id: X user ID.
--   - username: X handle (max 15 chars).
--   - badge: Verification bitmask (e.g., 16=PCF_LABEL).
-- Relationships: References communities; referenced by user_roles, posts, etc.
CREATE TABLE IF NOT EXISTS users (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    x_user_id VARCHAR(30) NOT NULL UNIQUE COMMENT 'Unique X user ID',
    username VARCHAR(15) NOT NULL COMMENT 'X handle without @ (max 15 chars per X rules)',
    display_name VARCHAR(50) NOT NULL COMMENT 'User display name (max 50 chars per X rules)',
    badge INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Bitmask: 0=NONE, 1=VERIFIED, 2=BUSINESS_VERIFIED, 4=GOVERNMENT_VERIFIED, 8=BOT_LABEL, 16=PCF_LABEL (Parody, Commentary, Fan)',
    is_global_admin TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '1 if global admin',
    is_disabled TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '1 if user cannot log in to dashboard',
    default_community_id BIGINT UNSIGNED COMMENT 'Preferred community for dashboard',
    last_action_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Last activity (post, login, etc.)',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (default_community_id) REFERENCES communities(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=10;

-- Table: posts
-- Purpose: Stores X posts with text, images, videos, or audios, and moderation status.
-- Key Columns:
--   - x_post_id: Unique X post ID.
--   - community_id, user_id: Links to tables.
--   - content_type: Bitmask (0=NONE, 1=TEXT, 2=IMAGE, 4=VIDEO, 8=AUDIO, combinable).
--   - parent_post_id: For replies.
--   - review_status, moderation_status: Moderation flags.
-- Relationships: References communities, users, posts; referenced by user_reputation, post_text, post_images, post_videos, post_audios, post_moderation_scores.
CREATE TABLE IF NOT EXISTS posts (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    x_post_id VARCHAR(30) NOT NULL UNIQUE COMMENT 'Unique X post ID',
    community_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    parent_post_id BIGINT UNSIGNED COMMENT 'NULL for original posts',
    content_type TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Bitmask: 0=NONE, 1=TEXT, 2=IMAGE, 4=VIDEO, 8=AUDIO, combinable (e.g., 15=TEXT+IMAGE+VIDEO+AUDIO)',
    post_url VARCHAR(255) NOT NULL COMMENT 'URL to X post',
    like_count INT UNSIGNED NOT NULL DEFAULT 0,
    reply_count INT UNSIGNED NOT NULL DEFAULT 0,
    review_status TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=UNFLAGGED, 1=FLAGGED, 2=REVIEWED',
    moderation_status TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=PENDING, 1=APPROVED, 2=HIDDEN, 3=DELETED',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (community_id) REFERENCES communities(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (parent_post_id) REFERENCES posts(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: post_text
-- Purpose: Stores text content for posts or manually added community announcements.
-- Key Columns:
--   - community_id: Links to communities.
--   - post_id: Optional link to posts (NULL for manual entries).
--   - fabricated_by: User who added manual message (NULL for post-derived).
--   - message: Text content.
-- Relationships: References communities, posts, users; referenced by embeddings.
-- Notes: Used for post-derived moderation text or manual dashboard messages (e.g., announcements).
CREATE TABLE IF NOT EXISTS post_text (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    community_id BIGINT UNSIGNED NOT NULL,
    post_id BIGINT UNSIGNED COMMENT 'NULL for manually fabricated/added dashboard messages',
    fabricated_by BIGINT UNSIGNED COMMENT 'User who added manual message, NULL for post-derived',
    message TEXT NOT NULL COMMENT 'Message text (e.g., "Community update")',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (community_id) REFERENCES communities(id) ON DELETE CASCADE,
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    FOREIGN KEY (fabricated_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: post_images
-- Purpose: Stores image attachments for posts with metadata.
-- Key Columns:
--   - community_id, post_id: Links to tables.
--   - x_content_url: X CDN image URL.
--   - width, height: Pixel dimensions.
--   - mime_type: e.g., image/jpeg.
--   - file_size: Size in bytes.
--   - alt_text: Accessibility text.
--   - is_nsfw: 0=false, 1=true.
--   - classification: ML label (e.g., harmful, safe).
--   - ordinal: Image order.
-- Relationships: References communities, posts; referenced by embeddings.
CREATE TABLE IF NOT EXISTS post_images (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    community_id BIGINT UNSIGNED NOT NULL,
    post_id BIGINT UNSIGNED NOT NULL,
    x_content_url VARCHAR(255) NOT NULL COMMENT 'URL to X CDN image',
    width INT UNSIGNED COMMENT 'Image width in pixels',
    height INT UNSIGNED COMMENT 'Image height in pixels',
    mime_type VARCHAR(50) COMMENT 'MIME type (e.g., image/jpeg, image/png, image/webp)',
    file_size INT UNSIGNED COMMENT 'File size in bytes',
    alt_text VARCHAR(255) COMMENT 'Accessibility alt text for SEO and screen readers',
    is_nsfw TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=false, 1=true',
    classification VARCHAR(50) COMMENT 'ML classification label (e.g., harmful, offensive, safe)',
    ordinal TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Order of images for a post',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (community_id) REFERENCES communities(id) ON DELETE CASCADE,
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: post_videos
-- Purpose: Stores video attachments for posts with metadata.
-- Key Columns:
--   - community_id, post_id: Links to tables.
--   - x_content_url: X CDN video URL.
--   - width, height: Pixel dimensions.
--   - mime_type: e.g., video/mp4.
--   - file_size: Size in bytes.
--   - duration: Video length in seconds.
--   - is_nsfw: 0=false, 1=true.
--   - classification: ML label (e.g., harmful, safe).
--   - ordinal: Video order.
-- Relationships: References communities, posts; referenced by embeddings.
CREATE TABLE IF NOT EXISTS post_videos (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    community_id BIGINT UNSIGNED NOT NULL,
    post_id BIGINT UNSIGNED NOT NULL,
    x_content_url VARCHAR(255) NOT NULL COMMENT 'URL to X CDN video',
    width INT UNSIGNED COMMENT 'Video width in pixels',
    height INT UNSIGNED COMMENT 'Video height in pixels',
    mime_type VARCHAR(50) COMMENT 'MIME type (e.g., video/mp4, video/webm)',
    file_size INT UNSIGNED COMMENT 'File size in bytes',
    duration INT UNSIGNED COMMENT 'Video duration in seconds',
    is_nsfw TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=false, 1=true',
    classification VARCHAR(50) COMMENT 'ML classification label (e.g., harmful, offensive, safe)',
    ordinal TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Order of videos for a post',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (community_id) REFERENCES communities(id) ON DELETE CASCADE,
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: post_audios
-- Purpose: Stores audio attachments for posts with metadata.
-- Key Columns:
--   - community_id, post_id: Links to tables.
--   - x_content_url: X CDN audio URL.
--   - mime_type: e.g., audio/mpeg.
--   - file_size: Size in bytes.
--   - duration: Audio length in seconds.
--   - is_nsfw: 0=false, 1=true.
--   - classification: ML label (e.g., harmful, safe).
--   - ordinal: Audio order.
-- Relationships: References communities, posts; referenced by embeddings.
CREATE TABLE IF NOT EXISTS post_audios (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    community_id BIGINT UNSIGNED NOT NULL,
    post_id BIGINT UNSIGNED NOT NULL,
    x_content_url VARCHAR(255) NOT NULL COMMENT 'URL to X CDN audio',
    mime_type VARCHAR(50) COMMENT 'MIME type (e.g., audio/mpeg, audio/wav)',
    file_size INT UNSIGNED COMMENT 'File size in bytes',
    duration INT UNSIGNED COMMENT 'Audio duration in seconds',
    is_nsfw TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=false, 1=true',
    classification VARCHAR(50) COMMENT 'ML classification label (e.g., harmful, offensive, safe)',
    ordinal TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Order of audios for a post',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (community_id) REFERENCES communities(id) ON DELETE CASCADE,
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: user_roles
-- Purpose: Defines user roles, status, and cached reputation in communities.
-- Key Columns:
--   - community_id, user_id: Links to communities and users.
--   - role: 0=USER, 1=MODERATOR, 2=ADMIN.
--   - flag: 0=NONE, 1=YELLOW, 2=RED.
--   - reputation: Cached total reputation score (-1.0 to 1.0).
-- Relationships: References communities, users; unique per user-community pair.
-- Notes: reputation is periodically updated from user_reputation.score to avoid recalculating deltas.
CREATE TABLE IF NOT EXISTS user_roles (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    community_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    role TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=USER, 1=MODERATOR, 2=ADMIN',
    status TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '0=INACTIVE, 1=ACTIVE',
    flag TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=NONE, 1=YELLOW, 2=RED',
    reputation FLOAT NOT NULL DEFAULT 0.0 COMMENT 'Cached total reputation score (-1.0 to 1.0), updated periodically from user_reputation.score',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (community_id) REFERENCES communities(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE (community_id, user_id) COMMENT 'One role per user per community'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: user_reputation
-- Purpose: Tracks reputation score changes (deltas) for users in communities.
-- Key Columns:
--   - community_id, user_id: Links to communities and users.
--   - post_id: Optional link to posts.
--   - score: Reputation delta (-1.0 to 1.0).
--   - reviewer_id: User ID or NULL for SYSTEM/LLM.
-- Relationships: References communities, users, posts, users (reviewer).
CREATE TABLE IF NOT EXISTS user_reputation (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    community_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    post_id BIGINT UNSIGNED COMMENT 'Related post ID, if applicable',
    score FLOAT NOT NULL DEFAULT 0.0 COMMENT 'Reputation delta (-1.0 to 1.0) for a specific action, positive for helpfulness, negative for violations',
    reason TEXT NOT NULL COMMENT 'Reason for reputation change',
    reviewer_id BIGINT UNSIGNED COMMENT 'User ID who reviewed, NULL for SYSTEM/LLM',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (community_id) REFERENCES communities(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE SET NULL,
    FOREIGN KEY (reviewer_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: moderation_categories
-- Purpose: Defines moderation categories with thresholds and actions.
-- Key Columns:
--   - community_id: Links to communities.
--   - name: Category name (e.g., spam, toxicity, helpfulness).
--   - soft_threshold, hard_threshold: Scores for triggering actions (0.0-1.0).
--   - soft_action_type, hard_action_type: Actions to take when thresholds are met.
--   - color: RRGGBBAA for UI dashboard visualization.
--   - weight: Scaling factor for reputation impact.
--   - is_active: Enable/disable category for moderation without deletion.
-- Relationships: References communities; referenced by post_moderation_scores.
-- Notes: is_active allows temporary disabling (e.g., during ML retraining or rule changes).
CREATE TABLE IF NOT EXISTS moderation_categories (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    community_id BIGINT UNSIGNED NOT NULL COMMENT 'Internal community ID',
    name VARCHAR(30) NOT NULL COMMENT 'Category name (e.g., spam, toxicity, helpfulness)',
    description TEXT COMMENT 'Category description',
    color INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'RRGGBBAA color code (e.g., 0xFF0000FF for red, stored as unsigned integer)',
    soft_threshold FLOAT NOT NULL COMMENT 'Soft threshold (0.0 to 1.0) for triggering actions like flagging, typically lower than hard threshold',
    soft_action_type TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=NO_ACTION, 1=FLAG_POST, 2=HIDE_POST, 3=NOTIFY_MODERATORS, 4=BAN_USER',
    hard_threshold FLOAT NOT NULL COMMENT 'Hard threshold (0.0 to 1.0) for triggering actions like hiding or banning, typically higher than soft threshold',
    hard_action_type TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=NO_ACTION, 1=FLAG_POST, 2=HIDE_POST, 3=NOTIFY_MODERATORS, 4=BAN_USER',
    weight FLOAT NOT NULL DEFAULT 1.0 COMMENT 'Scaling factor (0.0 to 2.0) for reputation impact, >1.0 amplifies (e.g., spam), <1.0 reduces (e.g., minor issues)',
    is_active TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '0=inactive, 1=active; disables category for moderation',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE (community_id, name) COMMENT 'Unique category name per community',
    FOREIGN KEY (community_id) REFERENCES communities(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: post_moderation_scores
-- Purpose: Stores ML or human-assigned scores for posts against moderation categories.
-- Key Columns:
--   - post_id, category_id: Links to posts and moderation_categories.
--   - score: ML or human score (0.0-1.0).
--   - confidence: ML model confidence (0.0-1.0).
--   - reputation_delta: Computed reputation impact (-1.0 to 1.0).
--   - created_by: User who set score (NULL for SYSTEM/LLM).
--   - model_type, model_version: ML model details.
--   - is_active: Enable/disable score without deletion.
-- Relationships: References posts, moderation_categories, users (created_by, last_updated_by).
-- Notes: is_active allows disabling individual scores (e.g., incorrect ML predictions) for training or auditing.
CREATE TABLE IF NOT EXISTS post_moderation_scores (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    post_id BIGINT UNSIGNED NOT NULL,
    category_id BIGINT UNSIGNED NOT NULL,
    score FLOAT NOT NULL COMMENT 'Score from 0.0 (benign) to 1.0 (severe) for the moderation category (e.g., spam likelihood)',
    confidence FLOAT NOT NULL COMMENT 'ML model confidence in the score, from 0.0 (uncertain) to 1.0 (certain)',
    reputation_delta FLOAT DEFAULT 0.0 COMMENT 'Reputation impact (-1.0 to 1.0), computed as score * moderation_categories.weight, positive for helpfulness, negative for violations',
    context_notes TEXT COMMENT 'LLM-generated context insights',
    model_type VARCHAR(20) NOT NULL COMMENT 'ML model type (e.g., grok, custom)',
    model_version VARCHAR(50) NOT NULL COMMENT 'ML model version (e.g., grok-beta)',
    training_label TINYINT COMMENT '0=NEGATIVE, 1=POSITIVE, NULL=UNLABELED',
    created_by BIGINT UNSIGNED COMMENT 'User ID who set score, NULL for SYSTEM/LLM',
    last_updated_by BIGINT UNSIGNED COMMENT 'User or bot ID who last updated',
    is_active TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '0=inactive, 1=active; disables score for training/auditing',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES moderation_categories(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (last_updated_by) REFERENCES users(id) ON DELETE SET NULL,
    UNIQUE (post_id, category_id, model_version) COMMENT 'One score per post per category per model'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: embeddings
-- Purpose: References Qdrant vectors for post text, images, videos, or audios.
-- Key Columns:
--   - community_id: Links to communities.
--   - post_type_id: Links to content (post_text, post_images, post_videos, or post_audios, based on type).
--   - type: Content type (0=TEXT, 1=IMAGE, 2=VIDEO, 3=AUDIO).
--   - model: ML model used (e.g., xai-grok).
--   - embedding_uuid: Qdrant vector UUID.
-- Relationships: References communities; post_type_id references post_text, post_images, post_videos, or post_audios based on type.
-- Notes: Application logic ensures post_type_id references the correct table based on type (0=post_text, 1=post_images, 2=post_videos, 3=post_audios).
-- Qdrant: Uses separate collections (text, image, video, audio) for optimized indexing.
-- Qdrant Payload: Includes community_id, post_type_id, post_id (derived from referenced table), type, model, created_at.
CREATE TABLE IF NOT EXISTS embeddings (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    community_id BIGINT UNSIGNED NOT NULL COMMENT 'Community ID',
    post_type_id BIGINT UNSIGNED COMMENT 'ID of the content, references post_text(id) if type=0, post_images(id) if type=1, post_videos(id) if type=2, post_audios(id) if type=3',
    `type` TINYINT UNSIGNED NOT NULL COMMENT '0=TEXT, 1=IMAGE, 2=VIDEO, 3=AUDIO',
    model VARCHAR(50) NOT NULL COMMENT 'Model used: xai-grok, all-mpnet-base-v2, clip-vit-base, etc.',
    embedding_uuid CHAR(36) NOT NULL UNIQUE COMMENT 'UUID for Qdrant vector',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (community_id) REFERENCES communities(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: user_bans
-- Purpose: Stores user bans in communities.
-- Key Columns:
--   - community_id, user_id: Links to tables.
--   - issued_by: User ID or NULL for SYSTEM/LLM.
--   - reason: Ban reason.
--   - expiry_at: Ban expiry (NULL for permanent).
-- Relationships: References communities, users, users (issued_by).
CREATE TABLE IF NOT EXISTS user_bans (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    community_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    issued_by BIGINT UNSIGNED COMMENT 'NULL for SYSTEM/LLM bans',
    reason TEXT NOT NULL,
    expiry_at TIMESTAMP NULL COMMENT 'NULL for permanent bans',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (community_id) REFERENCES communities(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (issued_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: notifications
-- Purpose: Stores system/community notifications.
-- Key Columns:
--   - community_id: Optional link to communities.
--   - user_id: Optional link to users.
--   - type: 0=POST, 1=SYSTEM.
--   - severity: 0=NORMAL, 1=HIGH, 2=CRITICAL.
--   - status: 0=PENDING, 1=VIEWED, 2=RESOLVED.
-- Relationships: References communities, users.
CREATE TABLE IF NOT EXISTS notifications (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    community_id BIGINT UNSIGNED COMMENT 'NULL for system-wide notifications',
    user_id BIGINT UNSIGNED COMMENT 'NULL for all users',
    `type` TINYINT UNSIGNED NOT NULL COMMENT '0=POST, 1=SYSTEM',
    severity TINYINT UNSIGNED NOT NULL COMMENT '0=NORMAL, 1=HIGH, 2=CRITICAL',
    message TEXT NOT NULL,
    status TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=PENDING, 1=VIEWED, 2=RESOLVED',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (community_id) REFERENCES communities(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: oauth_sessions
-- Purpose: Stores OAuth2 tokens for X users.
-- Key Columns:
--   - user_id: Links to users.
--   - access_token: OAuth token.
--   - expires_at: Token expiry.
-- Relationships: References users.
CREATE TABLE IF NOT EXISTS oauth_sessions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    access_token VARCHAR(255) NOT NULL,
    refresh_token VARCHAR(255),
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: moderation_logs
-- Purpose: Logs moderation actions on posts/users.
-- Key Columns:
--   - community_id: Optional link to communities.
--   - user_id: Moderator.
--   - target_user_id, target_post_id: Action targets.
--   - action_type: e.g., FLAG_POST.
-- Relationships: References communities, users, posts.
CREATE TABLE IF NOT EXISTS moderation_logs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    community_id BIGINT UNSIGNED COMMENT 'NULL for global actions',
    user_id BIGINT UNSIGNED NOT NULL COMMENT 'Moderator who performed the action',
    target_user_id BIGINT UNSIGNED COMMENT 'Target user, if applicable',
    target_post_id BIGINT UNSIGNED COMMENT 'Target post, if applicable',
    action_type VARCHAR(30) NOT NULL COMMENT 'e.g., FLAG_POST, HIDE_POST, BAN_USER',
    reason TEXT NOT NULL COMMENT 'Reason for action (e.g., "Spam post, score=0.7")',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (community_id) REFERENCES communities(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (target_user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (target_post_id) REFERENCES posts(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: appeals
-- Purpose: Stores ban appeals.
-- Key Columns:
--   - community_id, user_id: Links to tables.
--   - appeal_reason: Appeal text.
--   - status: 0=PENDING, 1=APPROVED, 2=REJECTED.
--   - reviewed_by: Reviewer user ID.
-- Relationships: References communities, users.
CREATE TABLE IF NOT EXISTS appeals (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    community_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    appeal_reason TEXT NOT NULL,
    status TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=PENDING, 1=APPROVED, 2=REJECTED',
    reviewed_by BIGINT UNSIGNED COMMENT 'Reviewer user ID',
    reviewed_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (community_id) REFERENCES communities(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: logs
-- Purpose: Stores system logs for debugging/auditing.
-- Key Columns:
--   - community_id, user_id: Optional links.
--   - component: e.g., auth, bot.
--   - level: 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR.
-- Relationships: References communities, users.
CREATE TABLE IF NOT EXISTS logs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    community_id BIGINT UNSIGNED COMMENT 'NULL for system-wide logs',
    user_id BIGINT UNSIGNED COMMENT 'Related user, if applicable',
    component VARCHAR(30) NOT NULL COMMENT 'e.g., auth, bot, websocket',
    level TINYINT UNSIGNED NOT NULL COMMENT '0=DEBUG, 1=INFO, 2=WARN, 3=ERROR',
    message TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (community_id) REFERENCES communities(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: notes
-- Purpose: Stores user notes (e.g., LLM-generated).
-- Key Columns:
--   - community_id, user_id: Links to tables.
--   - author_id: Note author (0-9 for SYSTEM/LLM, or users.id for human authors).
--   - visibility: 0=GLOBAL_ADMINS, 1=MODERATORS, 2=ADMINS.
-- Relationships: References communities, users.
CREATE TABLE IF NOT EXISTS notes (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    community_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    content TEXT NOT NULL,
    author_id BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0-9 for SYSTEM/LLM, or users.id for human authors',
    visibility TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=GLOBAL_ADMINS, 1=MODERATORS, 2=ADMINS',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (community_id) REFERENCES communities(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: settings
-- Purpose: Stores system/community settings.
-- Key Columns:
--   - community_id: Optional link to communities.
--   - key: Setting key (e.g., bot.enable_banning).
--   - value: Setting value.
--   - active: 0=inactive, 1=active.
-- Relationships: References communities.
CREATE TABLE IF NOT EXISTS settings (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    community_id BIGINT UNSIGNED COMMENT 'NULL for global settings',
    `key` VARCHAR(50) NOT NULL COMMENT 'Setting key (e.g., bot.enable_banning)',
    `value` TEXT NOT NULL COMMENT 'Setting value',
    active TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '0=inactive, 1=active',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (community_id) REFERENCES communities(id) ON DELETE SET NULL,
    UNIQUE (community_id, `key`) COMMENT 'Unique key per community or global'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: api_keys
-- Purpose: Stores API authentication tokens.
-- Key Columns:
--   - user_id: Links to users (0 for SYSTEM).
--   - token: SHA-256 hash (64 chars).
--   - name: Key name.
--   - expires_at: Optional expiry.
-- Relationships: References users.
CREATE TABLE IF NOT EXISTS api_keys (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0 for SYSTEM',
    token CHAR(64) NOT NULL UNIQUE COMMENT 'SHA-256 hash (64 hex chars)',
    name VARCHAR(50) NOT NULL,
    description VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Initialize global settings
INSERT INTO settings (community_id, `key`, `value`, active, created_at, updated_at)
VALUES
    (NULL, 'dash.name', 'X-Moderator', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP), -- Name of the dashboard
    (NULL, 'dash.description', 'An X-Moderator instance for moderating X Communities.', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP), -- Dashboard description
    (NULL, 'dash.tags', 'xmod,x-mod,x-moderator,x moderator,x,x-communities,communities,moderation,mods,moderators,admin,administrators,machine-learning,ml,machine,learning,machine learning', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP), -- Tags for discovery
    (NULL, 'dash.language', 'en_us', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP), -- Default language
    (NULL, 'dash.log_retention', '7889400', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP), -- Log retention in seconds (~91 days)
    (NULL, 'security.communities.add', '2', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP), -- Who can add communities: 0=GLOBAL ADMINISTRATORS ONLY, 1=ADMINS, 2=MODS
    (NULL, 'security.communities.edit', '2', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP), -- Who can edit communities: 0=GLOBAL ADMINISTRATORS ONLY, 1=ADMIN, 2=MODS
    (NULL, 'security.communities.remove', '2', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP), -- Who can remove communities: 0=GLOBAL ADMINISTRATORS ONLY, 1=ADMIN, 2=MODS
    (NULL, 'bot.enable_banning', 'false', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP), -- Enable/disable automated banning
    (NULL, 'bot.ui_scraper.aggressive', 'false', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP), -- Enable/disable aggressive UI scraping
    (NULL, 'user.max_appeal_count', '10', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP), -- Maximum ban appeals per user
    (NULL, 'user.idle_period', '1209600', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP); -- Idle period in seconds (~14 days)

-- Indexes for performance
CREATE INDEX idx_communities_x_community_id ON communities(x_community_id);
CREATE INDEX idx_users_x_user_id ON users(x_user_id);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_default_community_id ON users(default_community_id);
CREATE INDEX idx_user_roles_community_id ON user_roles(community_id);
CREATE INDEX idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX idx_user_reputation_community_id ON user_reputation(community_id);
CREATE INDEX idx_user_reputation_user_id ON user_reputation(user_id);
CREATE INDEX idx_user_reputation_post_id ON user_reputation(post_id);
CREATE INDEX idx_moderation_categories_community_id ON moderation_categories(community_id);
CREATE INDEX idx_moderation_categories_color ON moderation_categories(color);
CREATE INDEX idx_moderation_categories_is_active ON moderation_categories(is_active);
CREATE INDEX idx_post_moderation_scores_post_id ON post_moderation_scores(post_id);
CREATE INDEX idx_post_moderation_scores_category_id ON post_moderation_scores(category_id);
CREATE INDEX idx_post_moderation_scores_post_id_category_id ON post_moderation_scores(post_id, category_id);
CREATE INDEX idx_post_moderation_scores_created_by ON post_moderation_scores(created_by);
CREATE INDEX idx_post_moderation_scores_model_type ON post_moderation_scores(model_type);
CREATE INDEX idx_post_moderation_scores_is_active ON post_moderation_scores(is_active);
CREATE INDEX idx_post_moderation_scores_reputation_delta ON post_moderation_scores(reputation_delta);
CREATE INDEX idx_post_text_community_id ON post_text(community_id);
CREATE INDEX idx_post_text_post_id ON post_text(post_id);
CREATE INDEX idx_post_text_fabricated_by ON post_text(fabricated_by);
CREATE INDEX idx_embeddings_community_id ON embeddings(community_id);
CREATE INDEX idx_embeddings_post_type_id ON embeddings(post_type_id);
CREATE INDEX idx_embeddings_type ON embeddings(`type`);
CREATE INDEX idx_embeddings_embedding_uuid ON embeddings(embedding_uuid);
CREATE INDEX idx_posts_x_post_id ON posts(x_post_id);
CREATE INDEX idx_posts_community_id ON posts(community_id);
CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_posts_parent_post_id ON posts(parent_post_id);
CREATE INDEX idx_posts_content_type_community_id ON posts(content_type, community_id);
CREATE INDEX idx_post_images_post_id ON post_images(post_id);
CREATE INDEX idx_post_images_community_id ON post_images(community_id);
CREATE INDEX idx_post_images_ordinal ON post_images(ordinal);
CREATE INDEX idx_post_videos_post_id ON post_videos(post_id);
CREATE INDEX idx_post_videos_community_id ON post_videos(community_id);
CREATE INDEX idx_post_videos_ordinal ON post_videos(ordinal);
CREATE INDEX idx_post_audios_post_id ON post_audios(post_id);
CREATE INDEX idx_post_audios_community_id ON post_audios(community_id);
CREATE INDEX idx_post_audios_ordinal ON post_audios(ordinal);
CREATE INDEX idx_user_bans_community_id ON user_bans(community_id);
CREATE INDEX idx_user_bans_user_id ON user_bans(user_id);
CREATE INDEX idx_notifications_community_id ON notifications(community_id);
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_oauth_sessions_user_id ON oauth_sessions(user_id);
CREATE INDEX idx_moderation_logs_community_id ON moderation_logs(community_id);
CREATE INDEX idx_moderation_logs_user_id ON moderation_logs(user_id);
CREATE INDEX idx_moderation_logs_action_type ON moderation_logs(action_type);
CREATE INDEX idx_appeals_community_id ON appeals(community_id);
CREATE INDEX idx_logs_community_id ON logs(community_id);
CREATE INDEX idx_logs_created_at ON logs(created_at);
CREATE INDEX idx_notes_community_id ON notes(community_id);
CREATE INDEX idx_notes_user_id ON notes(user_id);
CREATE INDEX idx_settings_community_id_key ON settings(community_id, `key`);
CREATE INDEX idx_api_keys_user_id ON api_keys(user_id);
CREATE INDEX idx_api_keys_token ON api_keys(token);
