# Flutter BLoC + Clean Architecture

A set of instructions to help your AI coding assistant build Flutter apps with proper architecture with BLoC state management, clean layers, and consistent design themes.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat&logo=dart&logoColor=white)
![BLoC](https://img.shields.io/badge/BLoC-Pattern-blue)
![License](https://img.shields.io/badge/License-Apache%202.0-blue)

## What's Inside

- `SKILL.md`: The architecture rules and patterns
- `examples/`: Working code samples

## How It Works

```
UI → BLoC → Repository → Datasource → Backend
```

No business logic in widgets. No hardcoded colors. No magic numbers.

## Get Started

Install with the Skills CLI:

```bash
npx skills add https://github.com/abdelhakrazi/flutter-bloc-clean-architecture-skill --skill flutter-bloc-development
```

Or grab this repo and add it to your AI coding assistant manually.

## Examples

- [earnings/](./examples/earnings/): Full feature with feature-first structure (official BLoC pattern)
- [shared/data/](./examples/shared/data/): Shared datasources and models used across features
- [shared/widgets/](./examples/shared/widgets/): Reusable design-system-compliant widgets

## License

Apache 2.0
