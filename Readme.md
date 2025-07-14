You are an AI software engineer assigned to build a full-stack traffic violation reporting platform named **SnapChallan**. This citizen-driven web application will allow users to report real-life traffic violations by uploading photo or video evidence. The platform must be optimized for mobile users, implemented as a **Progressive Web App (PWA)** so it can be installed and work offline. The user experience should be fast, intuitive, and accessible under real-world constraints (4G/low-bandwidth areas). All uploaded evidence must include GPS and timestamp metadata (EXIF), and be linked to a verified user via **Aadhaar-based eKYC** (using OTP or FaceAuth via UIDAI API).

On the user side:

* Citizens should sign up using OTP verification, complete eKYC, and gain access to a simple interface to upload 1–3 images or a 30-second video.
* The evidence is stored in **MongoDB GridFS**, with metadata (timestamp, location, category) saved in the `violations` collection.
* AI inference should run on the uploaded content using **YOLOv8** (license plate recognition, object detection) and pre-fill data for officer validation.
* A reward system must credit the user with **40% of the challan amount** once the violation is approved and the fine is collected, which they can **withdraw via UPI** within 24 hours.

On the authority side:

* Create a secure login dashboard for traffic officers with **RBAC** roles.
* Officers can review pending cases with AI-analyzed suggestions, accept or reject evidence, and initiate challan issuance.
* Challans must integrate with government systems via **MoRTH Vahan/Sarathi e-Challan APIs**.
* Once fines are paid, update the reporter's wallet and trigger UPI payouts via payment gateway (e.g., Razorpay/Paytm/UPI push API).

---

### 🔧 Technology Stack (Detailed)

#### 🧩 Backend

* **Framework**: FastAPI (Python 3.12), asynchronous and type-safe.
* **Database**: MongoDB 7.x with **GridFS** for media storage, suitable for minimal data mutation and high I/O read patterns.
* **Object Detection**: YOLOv8 (PyTorch) for automated number plate and rule classification.
* **Authentication**: Keycloak (OAuth2.1 + JWT) for users and officers.
* **Caching & Queueing**: Redis (caching user sessions, AI tasks), Kafka (event stream for media upload, verification, payment).
* **Challan Issuance**: REST-based adapter service connecting to state e-challan APIs.
* **Payments**: UPI integration for payouts (preferably with bank or Razorpay UPI Collect).

#### 🧱 Frontend

* **Framework**: Next.js with TypeScript and TailwindCSS.
* **PWA Support**: Service Worker, background sync, offline media queuing.
* **Forms & Uploads**: Drag-and-drop media component with file size/type validation.
* **Officer Portal**: Vue.js web dashboard (or optional React microfrontend), includes case queue, map view, and audit history.

#### ☁️ Infrastructure & DevOps

* **Containerization**: Docker (for all services) with `docker-compose` for local dev.
* **Orchestration**: Kubernetes (K8s) for deployment with autoscaling and service discovery.
* **CI/CD**: GitHub Actions (test, build, deploy pipelines).
* **Monitoring**: Prometheus + Grafana (metrics), Loki (logging), Sentry (frontend errors).
* **Media Migration (optional)**: Use an internal job to migrate files from GridFS to S3/R2 for long-term archiving.

---

### ✅ Additional Requirements

* **Security**: TLS 1.3 for all endpoints, AES-256 encrypted user data at rest, Aadhaar number salted and hashed (SHA-256).
* **Accessibility**: Comply with WCAG 2.1 AA (mobile-friendly, screen reader support).
* **Audit Trail**: Every user or officer action must be logged immutably with timestamps.
* **Legal**: DPDP Act compliance, user consent stored, auto-deletion of data after 5 years or 1 year post-closure.

---

### 📦 Deliverables

* Complete GitHub repo with:

  * `backend/` (FastAPI services)
  * `frontend/` (Next.js PWA)
  * `dashboard/` (Officer portal)
  * `infra/` (Docker, K8s, Helm if needed)
  * `ai/` (YOLOv8 training & inference)
* Swagger/OpenAPI docs
* Database seed script with mock Aadhaar & sample violations
* Unit, integration, and e2e tests
* Architecture diagram in `docs/`
* CI/CD workflow with secrets for MongoDB, UIDAI sandbox, and payment APIs

you like me to turn this into a README, GitHub issue template, or agent script format?
