# Functional Requirements — Graph AI for Broadening the National Tax Net

**Source tags:** `P` = from Problem Statement · `U` = User's proposal · `S` = Suggested addition

---

## A. Synthetic Data Layer

| ID | Requirement | Source | Explanation |
|----|-------------|--------|-------------|
| FR-A1 | Generate synthetic, localized Pakistani civic data | P | Foundation of the whole system; must mimic real FBR/excise/civic records without using real PII. |
| FR-A2 | Produce 14 separate data silos: NADRA, FBR, Excise, Land/Revenue, Electricity, Gas, Travel, Luxury, Banking, Stocks/Securities, SECP business registry, Private school fees, Telecom, Foreign remittances | U/S | Each silo lives in its own file/table to realistically simulate fragmented government databases. |
| FR-A2a | Stocks/Securities silo (PSX holdings, CDC account, dividends, capital gains tax) | U | Major hidden asset class; dividend/capital-gain income vs. a zero-tax return is a clean deviation signal. |
| FR-A2b | SECP business/company registry (directorships, shareholdings, company-owned assets) | S | The benami goldmine — links Person→Company→Asset, the multi-hop chains that justify the GNN and graph depth. |
| FR-A2c | Private school fees silo (elite school enrolment + annual fee) | S | A real FBR non-filer indicator; a pure lifestyle signal that is hard to conceal and reads as authentic domain knowledge. |
| FR-A2d | Telecom silo (high-value postpaid bills, multiple SIM ownership, shared numbers) | S | Broad population coverage plus shared-phone links that feed entity resolution. |
| FR-A2e | Foreign remittances / offshore assets silo (inbound transfers, declared source) | S | Classic evasion route; funds entering with no matching declared income source. |
| FR-A3 | Inject realistic identity messiness (missing/typo CNIC, name spelling variants, address format differences) | P | Makes entity resolution non-trivial and proves the system handles real-world dirty data. |
| FR-A4 | Embed Urdu + romanized English name/address variants (e.g. محمد / Muhammad / Mohammad) | P | Explicitly graded academic complexity; tests cross-script entity matching. |
| FR-A5 | Plant labelled fraud archetypes: lifestyle–income mismatch, benami assets, identity fragmentation, asset rings, shell-company ownership (assets held via SECP companies) | S | Hidden ground truth lets us measure real precision/recall and forces graph-only detection. |
| FR-A6 | Maintain a secret ground-truth label set (who is fraud + which archetype) | S | Enables quantitative evaluation while the production pipeline stays unsupervised. |

---

## B. Entity Resolution (ER)

| ID | Requirement | Source | Explanation |
|----|-------------|--------|-------------|
| FR-B1 | Use CNIC as the primary join key when present | U | CNIC is Pakistan's universal identity number; exact match resolves the easy cases. |
| FR-B2 | Fall back to fuzzy/unsupervised ER when CNIC is missing or wrong | P | Links records that a plain CNIC join misses; this is a directly graded criterion. |
| FR-B3 | Match on name + address + family + phone using fuzzy + embedding similarity | P | Handles typos and cross-script text; produces candidate links beyond exact keys. |
| FR-B4 | Cluster matched records into one canonical "Person" entity | P | Aggregates a person's true footprint across all silos into a single identity. |
| FR-B5 | Report ER precision, recall, and F1 against ground truth | S | Surfaces a graded metric directly to judges; demonstrates algorithm quality. |

---

## C. Knowledge Graph

| ID | Requirement | Source | Explanation |
|----|-------------|--------|-------------|
| FR-C1 | Build a knowledge graph of Person, Company, Asset, Bill, Return, Travel, Account, Securities nodes with typed edges | P | Core deliverable; models relationships a flat table cannot express. Company nodes enable ownership-chain detection. |
| FR-C2 | Model multi-hop relationships (family, co-ownership, shared address) | S | Enables benami and ring detection; deepens the "graph relationship mapping" grade. |
| FR-C3 | Provide interactive graph visualization in the admin view | S | Makes graph depth visible and is the primary demo "wow" factor. |

---

## D. Anomaly Detection & Scoring

| ID | Requirement | Source | Explanation |
|----|-------------|--------|-------------|
| FR-D1 | Apply a GNN for unsupervised graph anomaly detection | P | Explicitly required; detects structural patterns (rings, benami) rules cannot encode. |
| FR-D2 | Compute rule-based signals (declared income vs. lifestyle/assets) | U | Transparent baseline that also feeds the explanation layer. |
| FR-D3 | Fuse GNN + rule signals into a single Tax Compliance Deviation Score | P/U | Single interpretable score combining learned and explicit evidence. |
| FR-D4 | Model tax adjustment (tax already paid at purchase offsets tax due) | U | Reflects real Pakistani withholding tax so user-facing tax math is correct. |
| FR-D5 | Classify each person into Red / Yellow / Green zones via configurable thresholds | U | Turns the continuous score into actionable triage for auditors. |

---

## E. Explainable Audit Trail

| ID | Requirement | Source | Explanation |
|----|-------------|--------|-------------|
| FR-E1 | Auto-generate a human-readable audit trail for every flagged person | P | Top-graded interpretability requirement; an auditor must understand *why*. |
| FR-E2 | Cite the concrete evidence behind each flag (assets, bills, links, score drivers) | P | Grounds the explanation in real records, not a black-box number. |
| FR-E3 | Surface which graph neighbors/edges drove the GNN score (GNNExplainer-style) | S | Bridges GNN + explainability; the hardest, most impressive combination. |

---

## F. User Dashboard

| ID | Requirement | Source | Explanation |
|----|-------------|--------|-------------|
| FR-F1 | Authenticated login separating user and admin roles | S | Two distinct dashboards require role-based access. |
| FR-F2 | Let a user view their own assets (vehicles, property, utilities, bank balance) | U | Citizen-facing transparency into their consolidated record. |
| FR-F3 | Show tax given vs. tax due vs. tax already deducted at purchase | U | Lets the user see their real net tax position and adjustments. |
| FR-F4 | Show the user their own compliance status | U | Personal visibility into where they stand before audit. |
| FR-F5 | Let a user *request* record corrections (admin approves) | S | Allows fixes without letting flagged users edit away evidence. |

---

## G. Admin Dashboard

| ID | Requirement | Source | Explanation |
|----|-------------|--------|-------------|
| FR-G1 | Access all users with filtering by category and zone | U | Central control surface for tax authority operators. |
| FR-G2 | Configure deviation-score thresholds for zones | U | Lets analysts tune sensitivity to their audit capacity. |
| FR-G3 | Open any flagged person to view graph, score, and audit trail | U/S | Single drill-down combining detection, evidence, and relationships. |
| FR-G4 | Review and approve/reject user correction requests and update records | U | Controlled data stewardship that preserves the audit trail. |
| FR-G5 | Display ER and detection quality metrics (precision/recall) | S | Proves system accuracy to evaluators on graded criteria. |

---

### Non-Functional (brief)
- **Unsupervised in production** — pipeline must work without labels (FR-A6 labels used only for evaluation).
- **Reproducibility** — seeded data generation so results are repeatable for the demo.
- **Separation of concerns** — raw records in PostgreSQL, graph in Neo4j, ML in the Python service, UI in Next.js.
