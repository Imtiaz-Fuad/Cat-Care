# Architecture.md

# Cat Care App - Architecture

## Overview

This document defines the architecture, project structure, and development standards for the Cat Care application. Every implementation should follow this document unless explicitly instructed otherwise.

---

# Tech Stack

## Frontend

* Flutter (latest stable)
* Material 3

## State Management

* Provider

Responsibilities:

* Global app state
* Authentication state
* Theme state
* Feature-specific state

Business logic should reside inside providers or service classes, **not inside widgets**.

---

## Routing

* go_router

Responsibilities:

* Authentication routing
* Deep linking support
* Route guards
* Nested navigation when necessary

---

## Backend

Firebase

Services:

* Firebase Authentication
* Cloud Firestore
* Firebase Storage
* Firebase Cloud Messaging (Future)
* Firebase Crashlytics
* Firebase Analytics (Future)
* Firebase Remote Config (Future)

---

## Database

Cloud Firestore

Collections should be normalized where practical and secured with proper Firestore Security Rules.

---

## Local Storage

### SharedPreferences

Used only for:

* Theme mode
* First launch flag
* User preferences
* Cached UI settings

Sensitive information must never be stored here.

---

## Networking

Use Dio for all external HTTP requests.

Do not call APIs directly from widgets.

---

## Logging

Use the `logger` package.

Never use `print()` in production code.

---

## Image Loading

Use `cached_network_image` for all remote images.

---

# Architecture Pattern

The application follows a **Feature-First architecture** with clear separation of responsibilities.

```
UI
│
├── Provider
│
├── Repository
│
├── Services
│
└── Firebase / External APIs
```

Rules:

* UI should never directly communicate with Firebase.
* Providers should never contain UI code.
* Services should never depend on Widgets.
* Repositories abstract data sources.
* Every layer should only know about the layer directly below it.

---

# Folder Structure

```
lib/

core/
    constants/
    errors/
    extensions/
    models/
    services/
    theme/
    utils/
    widgets/

features/

    authentication/
        models/
        providers/
        repositories/
        services/
        screens/
        widgets/

    home/
        providers/
        screens/
        widgets/

    cats/
        models/
        providers/
        repositories/
        services/
        screens/
        widgets/

    nutrition/
        ...

    health/
        ...

    reminders/
        ...

    ai/
        ...

    profile/
        ...

    settings/
        ...

routes/

main.dart
```

Every feature should be self-contained.

---

# Layer Responsibilities

## UI Layer

Contains:

* Screens
* Dialogs
* Widgets

Responsibilities:

* Display data
* Collect user input
* Listen to Providers

Must NOT:

* Query Firestore
* Execute business logic
* Parse JSON
* Call AI APIs

---

## Provider Layer

Responsibilities:

* Manage UI state
* Call repositories
* Handle loading state
* Handle error state
* Notify listeners

Providers should remain lightweight.

---

## Repository Layer

Responsibilities:

* Abstract Firebase and external services
* Combine multiple data sources when required
* Convert raw data into models

UI must never know where data comes from.

---

## Service Layer

Contains:

* Firebase services
* AI services
* Notification services
* Storage services

Each service should have one responsibility.

---

# Models

Every Firestore document should have a strongly typed model.

Models should include:

* fromJson()
* toJson()
* copyWith() (manual if needed)

Avoid using raw Map<String, dynamic> throughout the app.

---

# Error Handling

All exceptions should be caught inside repositories or services.

Providers should expose user-friendly error states.

Avoid exposing Firebase exceptions directly to the UI.

---

# Firestore Rules

The application must never rely on client-side validation alone.

Every collection must be protected using Firestore Security Rules.

Never use:

```
allow read, write: if true;
```

---

# Authentication Flow

```
Splash

↓

Check Firebase Authentication

↓

Authenticated
    ↓
Home

Not Authenticated
    ↓
Login
```

The app should automatically restore login sessions through Firebase Authentication.

SharedPreferences should not be used to determine authentication status.

---

# AI Architecture (Future)

```
Flutter
    │
    ▼
Firebase Authentication

Cloud Firestore

Firebase Storage

Cloud Functions
      │
      ▼
AI Providers
```

The Flutter application must never directly communicate with AI providers using secret API keys.

All AI requests should pass through a Cloud Function.

---

# Code Standards

## Prefer

* StatelessWidget whenever possible
* Small reusable widgets
* Composition over inheritance
* Feature isolation
* Named constructors
* Const constructors

---

## Avoid

* Massive widgets
* Business logic inside UI
* Duplicate code
* Global mutable variables
* Direct Firebase access from widgets

---

# Naming Conventions

Classes

```
CatRepository
```

Providers

```
CatProvider
```

Services

```
FirestoreService
```

Models

```
CatModel
```

Screens

```
HomeScreen
```

Widgets

```
CatCard
```

---

## Development Rules

1. Read catcare.prd before implementing product features.
2. Read catcare.design before implementing UI.
3. Follow architecture.md for technical decisions.
4. Do not invent health/care/food content.
5. Use placeholders or Firestore-backed content where content is not provided.
6. Do not introduce new dependencies without justification.
7. Do not change architecture without explaining why.
8. Do not implement multiple unrelated features in one task.
9. Run relevant tests after implementation.

# Performance Guidelines

* Paginate Firestore queries when needed.
* Cache remote images.
* Minimize unnecessary rebuilds.
* Dispose controllers appropriately.
* Avoid rebuilding large widget trees.

---

# Security

* Never hardcode secrets.
* Validate user input.
* Secure Firestore with rules.
* Use Firebase Authentication for user identity.
* Restrict Storage access through security rules.

---

# Testing

Minimum expectations:

* Provider unit tests
* Repository tests
* Widget tests for important screens

---


