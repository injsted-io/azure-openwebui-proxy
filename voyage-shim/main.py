from fastapi import FastAPI, Request, HTTPException
import os, httpx

VOYAGE_KEY = os.environ.get("VOYAGE_API_KEY")
DEFAULT_MODEL = os.environ.get("VOYAGE_MODEL", "rerank-2.5")  # << here
VOYAGE_URL = "https://api.voyageai.com/v1/rerank"

app = FastAPI()

@app.post("/rerank")
async def rerank(req: Request):
    if not VOYAGE_KEY:
        raise HTTPException(status_code=500, detail="VOYAGE_API_KEY not set")
    body = await req.json()

    try:
        query = body["query"]
        docs  = body["documents"]
    except KeyError as e:
        raise HTTPException(status_code=400, detail=f"Missing field: {e}")

    payload = {
        "model": body.get("model", DEFAULT_MODEL),  # << defaults to env
        "query": query,
        "documents": docs,
    }

    headers = {"Authorization": f"Bearer {VOYAGE_KEY}"}
    async with httpx.AsyncClient(timeout=30) as client:
        r = await client.post(VOYAGE_URL, headers=headers, json=payload)
        try:
            r.raise_for_status()
        except httpx.HTTPStatusError as e:
            return {"error": {"status": r.status_code, "body": r.text}}

        data = r.json()

    items = data.get("data") or data.get("results") or []
    normalized = [{
        "index": it["index"],
        "relevance_score": it.get("relevance_score") or it.get("score") or 0.0,
        "document": it.get("document"),
    } for it in items]

    return {"results": normalized}
