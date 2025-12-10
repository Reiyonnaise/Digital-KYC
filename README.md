# Digital KYC System – Process Analysis & Optimization

A detailed analysis of the Digital KYC workflow, highlighting failure points, system challenges, and proposed improvements.  
This project includes a failure analysis graph and a high-level system architecture diagram.

---

# 1. Introduction

Digital KYC (Know Your Customer) is a mandatory verification process used by banks to authenticate new customers.  
The bank in this case has implemented a Digital KYC system requiring:

- Uploading identity documents  
- Scanning documents using the mobile app  
- Completing real-time face verification  


This project focuses on identifying bottlenecks and proposing solutions to improve **drop-off rate, TAT, and KYC success rate**.

---

# 2. Objectives

- **Reduce customer dropout rate**
- **Improve Turnaround Time (TAT)** to within 15–20 seconds per stage  
- **Increase clarity** during the KYC flow  
- **Reduce rejection rate** caused by duplicates, poor scanning, or mismatch  
- **Minimize re-submissions and retries**, given users only have 3 attempts per stage  

---

# 3. Problem Statement

The Digital KYC system shows:

### High Rejection Causes
- Duplicate document entries  
- Server delays during upload/validation  
- Poor document scanning quality  
- Photo mismatch between uploaded and live image  

Failure Percentage Bar Graph

<img width="1979" height="1180" alt="output" src="https://github.com/user-attachments/assets/9fb573e6-a3e7-44d1-bf4f-f44aba9d8dde" />
### Failure Percentages per Stage

| Stage | Failure % |
|-------|-----------|
| Select Document Type | 15% |
| Scan Document | **35%** |
| Upload Document | 25% |
| KYC Check | 15% |
| KYC Approval | 10% |

## Key Insight

<span style="color:red;">The <b>scanning</b> and <b>uploading</b> steps show the greatest friction.</span>

### Additional Issues
- Slow server response  
- 3-attempt limit  
- Insufficient user instructions  

---

# 4. Solutions

- Improve Document Scanning
- Optimize Server Performance
- Duplicate KYC Detection
- UX Improvements
- Better Photo Matching
- Intelligent Retry Handling
- Help & Support Guide
  
### Tech Stack
- Mobile client

Flutter — single codebase for Android + iOS, good camera & file APIs.

- Backend

FastAPI (Python) — lightweight, async, easy to build REST endpoints.

- Storage

SQLite (dev) or Postgres (small production) — Postgres if you want ACID & SQL features.


- File storage

Local disk for prototype; AWS S3 (or DigitalOcean Spaces) for production.

- CI/CD

GitHub Actions to run tests & deploy.


### Installation

1. Clone the repository
   ```bash
   git clone <repository-url>
   cd Digital_KYC
   ```

2. Install dependencies
   ```bash
   flutter pub get
   ```

3. Run the development server
   ```bash
   flutter run
   ```

4. Run in Chrome or windows

---



# 5. System Architecture Diagram 


    flowchart TD
    A[Open Bank App] --> B[Select Document Type]
    B --> C[Scan Document]
    C --> D[Upload Document]
    D --> E[KYC Check]
    E --> F{KYC Valid?}
    
    F -->|Yes| G[KYC Approved]
    F -->|No| H{Attempts < 3?}

    H -->|Yes| I[Retry - Provide guidance and re-scan/upload]
    I --> C

    H -->|No| J[KYC Rejected - Show reason & Support options]



```mermaid
flowchart LR
  %% Mobile & user
  Mobile[Mobile App / User] -->|Upload scan/photo / API call| API[API Gateway]

  %% API and Services
  API --> Auth[Auth Service]
  API --> ScanSvc[Document Processing Service]
  API --> FaceSvc[Face Match Service]
  API --> Queue[Message Queue]

  %% Processing
  ScanSvc --> OCR[OCR Engine]
  ScanSvc --> ImageEnhance[Image Enhance / Glare/Blur Detect]
  FaceSvc --> FaceModel[Face Match Model]

  %% Persistence & caches
  OCR --> DB[(KYC Database)]
  FaceModel --> DB
  ScanSvc --> Cache[Cache / CDN]
  API --> Monitoring[Monitoring & Logging]
  Admin[Backoffice / Manual Review] --> DB

