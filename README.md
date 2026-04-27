# Yacht Reservation App

> Author: Mansoor Ahmad | Date: April 2026

---

## Table of Contents

1. [Solution Overview](#solution-overview)
2. [Architecture Decisions](#architecture-decisions)
3. [Data Model](#data-model)
4. [Apex Classes & Services](#apex-classes--services)
5. [LWC Components](#lwc-components)
6. [Integration Design](#integration-design)
7. [Security Model](#security-model)
8. [Experience Cloud Setup](#experience-cloud-setup)
9. [Configuration & Custom Metadata](#configuration--custom-metadata)
10. [Testing](#testing)
11. [Running a Demo](#running-a-demo)
12. [Known Limitations & Production Recommendations](#known-limitations--production-recommendations)
13. [Assumptions & Items Left Out](#assumptions--items-left-out)
14. [AI Tools Used](#ai-tools-used)

---

## Solution Overview

A guest-facing Yacht Reservation portal built on Salesforce Experience Cloud (LWR). Unauthenticated guests can search available yachts by type, date, and party size; browse results with infinite scroll; view yacht details; and complete a reservation — all without logging in.

The solution is designed as if the availability and reservation APIs are real external HTTP endpoints served by a separate Salesforce org, with a clean interface abstraction that allows swapping the mock for a live integration with zero code changes.

### Guest Journey

```
Hero Landing Page
      ↓ (Search Available Yachts)
Search Filters (Type / Date / Party Size)
      ↓ (Search)
Yacht Grid — 9 cards, available first, infinite scroll
      ↓ (Click card)
Detail Panel — specs, price, availability
      ↓ (Enter name + email → Reserve Now)
Confirmation — reference number + email sent to guest
```

---

## Architecture Decisions

### Why Custom Objects Over Standard Objects

`Product2` was evaluated as a candidate for Yacht but rejected because:

- Pricebook/Pricebook Entry is designed for catalogue pricing, not date-based dynamic availability
- Guest User + Product2 sharing requires significantly more configuration
- Custom objects give cleaner semantics and explicit guest permission control

### Why Interface-Based Provider Pattern

For Yacht Reservation and YachtAvailability, the callouts are abstracted behind `IAvailabilityProvider` and `IReservationProvider` interfaces with two implementations each:

- `MockAvailabilityProvider` / `MockReservationProvider` — used in dev/test
- `ExternalAvailabilityProvider` / `ExternalReservationProvider` — real HTTP callouts

Its controlled by `Yacht_Integration_Settings__mdt.Use_Mock_Provider__c`. An admin can flip between mock and real with no code deployment. 

### Why Nebula Logger Over Custom Log Object

Nebula Logger (managed package) was chosen over a custom `Integration_Error_Log__c` object because:

- Production-grade, community-maintained, battle-tested
- Provides log levels, async saving, related record linking, and a Lightning dashboard
- Exception: if the client has strict managed package restrictions, a custom object is the fallback

### Why `without sharing` on YachtReservationService

Guest users in Salesforce cannot own records. `Yacht_Reservation__c` uses a Lookup (not Master-Detail) to `Yacht__c` with OWD Private. 
Creating a reservation record in guest context requires `without sharing` to run in system context.

Input validation, party size checks, and idempotency are all enforced before the DML operation. `WITH SECURITY_ENFORCED` is applied to all SOQL queries within the class.

---

## Data Model

### Objects and Key Fields

#### `Yacht_Type__c`
| Field | API Name | Type | Purpose |
|---|---|---|---|
| Yacht Type Name | Name | Text | Display name |
| Description | Description__c | Long Text | Type description |
| Is Active | Is_Active__c | Checkbox | Filter active types only |
| Display Order | Display_Order__c | Number | Controls dropdown sort order |

#### `Yacht__c`
| Field | API Name | Type | Purpose |
|---|---|---|---|
| Yacht Name | Name | Text | Display name |
| Yacht Type | Yacht_Type__c | Master-Detail | Parent type |
| Capacity | Capacity__c | Number | Max guests |
| Minimum Party Size | Minimum_Party_Size__c | Number | Min guests |
| Headline | Headline__c | Text | Card subtitle |
| Description | Description__c | Long Text | Full description |
| Image URL | Image_URL__c | URL | Card/detail image |
| Is Active | Is_Active__c | Checkbox | Exclude inactive yachts |
| External Yacht ID | External_Yacht_ID__c | Text | External system reference, unique |

#### `Yacht_Availability__c`
| Field | API Name | Type | Purpose |
|---|---|---|---|
| Yacht | Yacht__c | Master-Detail | Parent yacht |
| Available Date | Available_Date__c | Date | Date of availability |
| Is Available | Is_Available__c | Checkbox | Availability flag |
| Price | Price__c | Currency | Price for this date |
| Last Synced | Last_Synced__c | DateTime | Cache freshness indicator |
| External Availability ID | External_Availability_ID__c | Text | Upsert key from external system |

> Availability records are a **local cache** populated by the external API callout. The `External_Availability_ID__c` field is used as the upsert key to prevent duplicate records.

#### `Yacht_Reservation__c`
| Field | API Name | Type | Purpose |
|---|---|---|---|
| Reservation Number | Name | Auto Number | RES-00001 format |
| Yacht | Yacht__c | Lookup | Reserved yacht |
| Reservation Date | Reservation_Date__c | Date | Date of booking |
| Party Size | Party_Size__c | Number | Number of guests |
| Guest Name | Guest_Name__c | Text | Guest full name |
| Guest Email | Guest_Email__c | Email | Guest email for confirmation |
| Status | Status__c | Picklist | Pending / Confirmed / Failed / Cancelled |
| Total Price | Total_Price__c | Currency | Price at time of booking |
| Confirmation Number | Confirmation_Number__c | Text | From external system |
| External Reference ID | External_Reference_ID__c | Text | External system ID |
| Idempotency Key | Idempotency_Key__c | Text | YachtId+Date+Email composite, unique |

> `Idempotency_Key__c` prevents duplicate reservations within the same session. Built as `YachtId_Date_Email` — unique constraint enforced at database level.

---

## Apex Classes & Services

### Class Hierarchy

```
YachtSearchController          ← thin @AuraEnabled controller, no business logic
├── YachtSearchService         ← search, filter, paginate, sort
│   └── YachtAvailabilityService  ← fetch & cache availability
│       ├── IAvailabilityProvider (interface)
│       │   ├── ExternalAvailabilityProvider  ← real HTTP callout
│       │   └── MockAvailabilityProvider      ← controlled test data
│
├── YachtReservationService    ← validate, idempotency, reserve, email
│   ├── IReservationProvider (interface)
│   │   ├── ExternalReservationProvider  ← real HTTP callout
│   │   └── MockReservationProvider      ← controlled test data
│   └── YachtConfirmationEmailService    ← plain text confirmation email
│
├── YachtItemWrapper           ← DTO: individual yacht card data
├── YachtSearchResultWrapper   ← DTO: paginated search result
└── YachtException             ← domain exception class
```

### Key Methods

| Class | Method | Purpose |
|---|---|---|
| `YachtSearchController` | `searchYachts` | AuraEnabled entry point for search |
| `YachtSearchController` | `getYachtTypes` | Returns active types for filter dropdown |
| `YachtSearchController` | `reserveYacht` | AuraEnabled entry point for reservation |
| `YachtSearchService` | `searchYachts` | Queries, filters, fetches availability, sorts, paginates |
| `YachtAvailabilityService` | `fetchAvailability` | Calls provider, upserts availability cache |
| `YachtReservationService` | `reserve` | Validates, checks idempotency, calls provider, saves record, sends email |
| `YachtConfirmationEmailService` | `sendConfirmation` | Sends plain text booking confirmation |

### Security Patterns Used

- `with sharing` on all classes except `YachtReservationService` (documented exception)
- `WITH SECURITY_ENFORCED` on all SOQL queries
- `Security.stripInaccessible(AccessType.READABLE, ...)` before returning records to LWC
- Named Credential for all external callouts — endpoint never hardcoded
- Input validation in Apex, not only in LWC

---

## LWC Components

| Component | Exposed | Purpose |
|---|---|---|
| `yachtReservationApp` | ✅ Page | Root container. Manages hero/search state transition |
| `yachtSearchFilters` | ✅ Default | Type dropdown, date picker, party size input. Publishes to LMS |
| `yachtResultsGrid` | ❌ | Subscribes to LMS, renders card grid, manages infinite scroll |
| `yachtCard` | ❌ | Individual yacht card — image, price badge, availability pill |
| `yachtDetailPanel` | ❌ | Right panel (desktop) / modal (mobile). Guest form + reserve action |

### Component Communication

| Pattern | Used For |
|---|---|
| Lightning Message Service (LMS) | Search params from `yachtSearchFilters` → `yachtResultsGrid` and `yachtReservationApp` |
| Custom Events (bubbling) | `yachtcard` → `yachtResultsGrid` → `yachtReservationApp` on yacht selection |
| `@api` properties | Parent → child data passing (yacht data, search date, party size) |

### Infinite Scroll

Implemented using the browser-native `IntersectionObserver` API watching a sentinel `<div>` at the bottom of the grid. When the sentinel enters the viewport, the next page of results is fetched. The observer is connected in `renderedCallback` and disconnected in `disconnectedCallback` to prevent memory leaks.

`this.template.querySelector('.scroll-sentinel')` is used rather than `lwc:ref` for maximum LWR compatibility.

### Theme Inheritance

Components use CSS custom properties that resolve to Experience Cloud site theme tokens:

```css
background: var(--lwc-colorBackground, #0a1628);
font-family: var(--lwc-fontFamily);
border-radius: var(--lwc-borderRadiusMedium);
```

---

## Integration Design

### Named Credential Setup

| | |
|---|---|
| **External Credential** | `Yacht_Reservation_External_Org` — No Authentication (mock) |
| **Named Credential** | `Yacht_Reservation_API` — URL: `https://mock.yacht-reservation-api.example.com` |
| **Principal** | `GuestAccess` — Named Principal |
| **Permission Set Mapping** | `Yacht_Guest_User_PS` → `GuestAccess` |

In production, swapping to a real Salesforce org requires only:
1. Updating the Named Credential URL
2. Changing the External Credential authentication protocol to OAuth 2.0 JWT
3. No code changes

### Availability Flow

```
Guest clicks Search
      ↓
YachtSearchController.searchYachts (AuraEnabled, cacheable=false)
      ↓
YachtSearchService.searchYachts
      ↓  queries Yacht__c with SOQL filters + LIMIT/OFFSET
      ↓
YachtAvailabilityService.fetchAvailability
      ↓  calls IAvailabilityProvider.getAvailability
      ↓  (Mock: returns controlled data | Real: HTTP POST to Named Credential)
      ↓  upserts Yacht_Availability__c cache records
      ↓
Returns YachtSearchResultWrapper with availability + pricing overlaid
      ↓
LWC renders cards, available first
```

### Reservation Flow

```
Guest enters name + email → clicks Reserve Now
      ↓
YachtSearchController.reserveYacht (AuraEnabled)
      ↓
YachtReservationService.reserve
      ↓  validates party size, date, yacht capacity
      ↓  checks idempotency key (prevents duplicates)
      ↓  calls IReservationProvider.submitReservation
      ↓  (Mock: returns CNF-XXXXXXXX | Real: HTTP POST to Named Credential)
      ↓  inserts Yacht_Reservation__c (Confirmed or Failed)
      ↓  marks Yacht_Availability__c.Is_Available__c = false
      ↓  calls YachtConfirmationEmailService.sendConfirmation
      ↓
Returns ReservationResult to LWC
      ↓
UI shows confirmation with reference number
```

---

## Security Model

### Guest User Profile

| Layer | Configuration |
|---|---|
| OWD — Yacht_Type__c | Public Read Only |
| OWD — Yacht__c | Controlled by Parent (inherits from Yacht_Type__c) |
| OWD — Yacht_Availability__c | Controlled by Parent (inherits from Yacht__c) |
| OWD — Yacht_Reservation__c | Private |
| Permission Set | Yacht_Guest_User_PS assigned to site Guest User |
| Apex Class Access | YachtSearchController accessible to Guest User |

### Permission Set: Yacht_Guest_User_PS

| Object | Create | Read | Edit | Delete | ViewAll |
|---|---|---|---|---|---|
| Yacht_Type__c | ❌ | ✅ | ❌ | ❌ | ❌ |
| Yacht__c | ❌ | ✅ | ❌ | ❌ | ❌ |
| Yacht_Availability__c | ❌ | ✅ | ❌ | ❌ | ❌ |
| Yacht_Reservation__c | ✅ | ✅ | ❌ | ❌ | ❌ |

> Guest users can create reservations but cannot view other guests' bookings (ViewAll: false, OWD: Private).

---

## Experience Cloud Setup

### Site Configuration

| Setting | Value |
|---|---|
| Site Name | yatch-reservation-portal |
| Framework | Lightning Web Runtime (LWR) — Enhanced |
| URL | `https://orgfarm-6f607d433e-dev-ed.develop.my.site.com/yachts` |
| Page | Yacht Reservation — sldsOneColLayout |
| Component | `c-yacht-reservation-app` |
| Guest Access | Enabled |
| Asset File Access | Enabled for guest users |

### Setup Steps

1. Enable Digital Experiences in Setup
2. Create LWR site using Build Your Own template
3. Install Nebula Logger unlocked package
4. Deploy all metadata: `sf project deploy start --source-dir force-app/main/default`
5. Configure OWD: Yacht_Type__c → Public Read Only, Yacht_Reservation__c → Private
6. Assign `Yacht_Guest_User_PS` to site Guest User profile
7. Enable Guest User file access in Site Preferences
8. In Experience Builder: create new page → sldsOneColLayout → drag `yachtReservationApp`
9. Publish site
10. Add sample Yacht Type and Yacht records with image URLs

---

## Configuration & Custom Metadata

All magic numbers and integration flags are stored in `Yacht_Integration_Settings__mdt`:

| Field | Default | Purpose |
|---|---|---|
| Use_Mock_Provider__c | true | Toggles mock vs real integration provider |
| Page_Size__c | 9 | Cards per page (drives LIMIT in SOQL) |
| Max_Party_Size__c | 20 | Upper bound for party size validation |
| API_Timeout_Ms__c | 10000 | HTTP callout timeout in milliseconds |

To switch to real integration: set `Use_Mock_Provider__c = false` and update Named Credential URL. No deployment required.

---

## Testing

### Running Tests

```bash
sf apex run test \
  --class-names YachtAvailabilityServiceTest,YachtReservationServiceTest,YachtSearchServiceTest,YachtSearchControllerTest \
  --result-format human \
  --wait 10
```

### Coverage Summary

| Class | Tests | Result |
|---|---|---|
| YachtAvailabilityServiceTest | 6 | ✅ Pass |
| YachtReservationServiceTest | 8 | ✅ Pass |
| YachtSearchServiceTest | 8 | ✅ Pass |
| YachtSearchControllerTest | 7 | ✅ Pass |
| **Total** | **33** | **100% Pass** |

### Test Patterns Used

- `@TestVisible` static `providerOverride` for clean mock injection — no `HttpCalloutMock` needed
- `@TestSetup` for efficient shared test data
- `MockAvailabilityProvider` supports per-yacht availability and price overrides
- `MockReservationProvider` supports `shouldFail` flag to test error paths
- All assertions include meaningful failure messages

---

## Running a Demo

1. Open incognito browser
2. Navigate to `https://orgfarm-6f607d433e-dev-ed.develop.my.site.com/yachts`
3. Click **Search Available Yachts**
4. Select a yacht type, pick a future date, enter party size (e.g. 4)
5. Click **Search**. Maximum 9 yachts loaded on first load
6. Scroll down to trigger infinite scroll (loads next page)
7. Click an available yacht card — detail panel opens on right
8. Enter name and email → click **Reserve Now**
9. Confirmation appears with reference number
10. Reserved yacht shows as Unavailable — card is greyed out

---

## Known Limitations & Production Recommendations

| Limitation | Current | Production Recommendation |
|---|---|---|
| Pagination | SOQL OFFSET (ceiling: 2000) | Keyset pagination on indexed field |
| Availability caching | No TTL — cached until next search | Platform Cache (Org tier) with TTL |
| Real-time availability | Poll on search only | Change Data Capture from external org |
| Image hosting | Salesforce Files / static URLs | Salesforce CMS with CDN delivery |
| Guest identity | Name + email collected at reservation | Experience Cloud authenticated guest or OTP verification |
| Email confirmation | `Messaging.SingleEmailMessage` | Org-wide email template with branding |
| Trigger framework | No triggers required in this solution | FFLIB / Apex Trigger Actions Framework if DML events needed |
| Async reservation | Synchronous callout | Platform Events + Queueable for resilience |

---

## Assumptions & Items Left Out

- **No admin UI** — yacht and type management is done directly in Salesforce. An admin Lightning App page would be the next addition.
- **No authentication** — guests are unauthenticated. Production would evaluate OTP email verification or Experience Cloud registered users.
- **Single currency** — AED assumed. Multi-currency support would require currency field configuration.
- **Email delivery** — confirmation email requires org Deliverability set to "All Email". Not configured by default in Developer Edition.
- **No cancellation flow** — reservations can be cancelled by an admin but there is no guest-facing cancellation UI.
- **External org not connected** — the Named Credential points to a mock endpoint. The `ExternalAvailabilityProvider` and `ExternalReservationProvider` classes are production-ready but untested against a live org.

---

## AI Tools Used

- Deepseek: used as documentation aide for generating the readme file content. Also used for CSS styling assistance.
- Agentforce Vibes: used for boiler-plate code generation assistant throughout this project.
