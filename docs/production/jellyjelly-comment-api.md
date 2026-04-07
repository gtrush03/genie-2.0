# JellyJelly Comment API — Reverse-Engineered (2026-04-06)

## Base URL
`https://api.jellyjelly.com/v3`

## Authentication
Bearer token (Supabase-issued JWT) in `Authorization` header.

## Endpoints

### GET Comments
```
GET /v3/jelly/{clip_id}/comment
Authorization: Bearer {token}
```
Response (200):
```json
{
  "status": "success",
  "total": 1,
  "page": 1,
  "page_size": 15,
  "comments": [
    {
      "id": 14137,
      "content": "test",
      "created_at": "2026-04-06T20:29:43.284014+00:00",
      "user": {
        "id": "13b132a6-6520-46b6-a563-2d6d2ce5149f",
        "username": "Genie",
        "full_name": "Genie",
        "pfp_url": null,
        "wobbles_badge_no": null
      }
    }
  ]
}
```

**Pagination:** `page` and `page_size` fields returned (default page_size=15). Likely supports `?page=2` query param.

### POST Comment
```
POST /v3/jelly/{clip_id}/comment
Authorization: Bearer {token}
Content-Type: application/json

{"content": "Your comment text here"}
```
Response (201):
```json
{
  "status": "success",
  "comment": {
    "id": "14137",
    "created_at": "2026-04-06T20:29:43.284014+00:00"
  }
}
```

**Required field:** `content` (string). All other field names (`text`, `body`, `comment`, `message`) return 400 with `"content is required"`.

### DELETE Comment
```
DELETE /v3/jelly/{clip_id}/comment/{comment_id}
Authorization: Bearer {token}
```
Response (200):
```json
{"status": "success", "message": "Comment deleted"}
```

## Key Findings
- Endpoint is **singular** `/comment` not `/comments`
- Comments are **flat** (no threading). `parent_id` and `reply_to` fields are accepted in POST without error but silently ignored (not returned in GET).
- Comment IDs are numeric integers (returned as string in POST response, integer in GET response)
- User info is auto-populated from the JWT (username, full_name, pfp_url, wobbles_badge_no)
- George's user ID: `13b132a6-6520-46b6-a563-2d6d2ce5149f`, username: `Genie`

## Invalid Endpoints (404/400)
- `/v3/jelly/{id}/comments` -> 400 "Invalid option comments"
- `/v3/jelly/{id}/replies` -> 400 "Invalid option replies"  
- `/v3/comments?jelly_id={id}` -> 404 "Resource not found"

## Example: Post a Comment
```bash
curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"content":"Hello from Genie!"}' \
  "https://api.jellyjelly.com/v3/jelly/01KND409VGCXB4WDTW4T1X27MB/comment"
```
