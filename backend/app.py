# backend/app.py
import os
import uuid
from typing import Optional
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from pathlib import Path
from datetime import datetime

# Config
DATA_DIR = Path("data")
UPLOADS_DIR = DATA_DIR / "uploads"
UPLOADS_DIR.mkdir(parents=True, exist_ok=True)

app = FastAPI(title="Simple Digital KYC Backend")

# Allow requests from emulator and other local clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # in prod restrict this
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# In-memory store for demo (replace with DB in prod)
class KycRecord(BaseModel):
    kyc_id: str
    customer_id: str
    doc_type: Optional[str] = None
    doc_number: Optional[str] = None
    created_at: datetime
    status: str  # IN_PROGRESS / APPROVED / REJECTED
    rejection_reason: Optional[str] = None
    paths: dict = {}

KYCS: dict[str, KycRecord] = {}

# Helpers
def _save_upload(kyc_id: str, file: UploadFile, prefix: str) -> str:
    """
    Save uploaded file under uploads/<kyc_id>/<prefix>_<uuid>_<filename>
    Returns relative path string.
    """
    user_dir = UPLOADS_DIR / kyc_id
    user_dir.mkdir(parents=True, exist_ok=True)
    safe_name = f"{prefix}_{uuid.uuid4().hex}_{Path(file.filename).name}"
    dest = user_dir / safe_name
    with dest.open("wb") as f:
        f.write(file.file.read())
    return str(dest)

# --- Endpoints ---

@app.post("/kyc/start")
async def start_kyc(
    customer_id: str = Form(...),
    doc_type: Optional[str] = Form(None),
):
    """
    Start a KYC session. Expects form fields: customer_id, doc_type (optional).
    Returns {"kyc_id": "...", "message": "..."}
    """
    kyc_id = uuid.uuid4().hex
    rec = KycRecord(
        kyc_id=kyc_id,
        customer_id=customer_id,
        doc_type=doc_type,
        created_at=datetime.utcnow(),
        status="IN_PROGRESS",
        paths={},
    )
    KYCS[kyc_id] = rec
    return {"kyc_id": kyc_id, "message": "KYC started", "status": rec.status}

@app.post("/kyc/upload-document")
async def upload_document(
    kyc_id: str = Form(...),
    doc_number: str = Form(...),
    file: UploadFile = File(...),
):
    """
    Upload document file and doc_number.
    """
    rec = KYCS.get(kyc_id)
    if rec is None:
        raise HTTPException(status_code=404, detail="KYC id not found")

    path = _save_upload(kyc_id, file, "document")
    rec.doc_number = doc_number
    rec.paths["document"] = path

    # (demo) simple check: if doc_number looks invalid we mark REJECTED later
    rec.status = "IN_PROGRESS"

    return {"message": "Document uploaded", "path": path}

@app.post("/kyc/upload-selfie")
async def upload_selfie(
    kyc_id: str = Form(...),
    file: UploadFile = File(...),
):
    rec = KYCS.get(kyc_id)
    if rec is None:
        raise HTTPException(status_code=404, detail="KYC id not found")

    path = _save_upload(kyc_id, file, "selfie")
    rec.paths["selfie"] = path
    rec.status = "IN_PROGRESS"
    return {"message": "Selfie uploaded", "path": path}

@app.post("/kyc/upload-live-selfie")
async def upload_live_selfie(
    kyc_id: str = Form(...),
    file: UploadFile = File(...),
):
    rec = KYCS.get(kyc_id)
    if rec is None:
        raise HTTPException(status_code=404, detail="KYC id not found")

    path = _save_upload(kyc_id, file, "live_selfie")
    rec.paths["live_selfie"] = path

    # DEMO verification logic (stub)
    # - If doc number missing => reject
    # - If doc number contains "REJ" => reject
    # - else approve
    if not rec.doc_number:
        rec.status = "REJECTED"
        rec.rejection_reason = "Missing document number"
        return {"message": "Live selfie uploaded, but KYC rejected", "status": rec.status}
    if "REJ" in str(rec.doc_number).upper():
        rec.status = "REJECTED"
        rec.rejection_reason = "Document failed automated checks"
        return {"message": "Live selfie uploaded, but KYC rejected", "status": rec.status}

    # otherwise approve
    rec.status = "APPROVED"
    return {"message": "KYC completed and approved", "status": rec.status}

@app.get("/kyc/status/{kyc_id}")
async def get_status(kyc_id: str):
    rec = KYCS.get(kyc_id)
    if rec is None:
        raise HTTPException(status_code=404, detail="KYC id not found")
    return {
        "kyc_id": rec.kyc_id,
        "status": rec.status,
        "rejection_reason": rec.rejection_reason,
        "paths": rec.paths,
        "message": f"Status is {rec.status}",
    }

# Simple health endpoint
@app.get("/health")
async def health():
    return {"status": "ok"}
