# Salesforce Cloud Hub

A comprehensive Salesforce engineering repository for Apex, LWC (Lightning Web Components), CPQ, integrations, automation and reusable architecture patterns.

## Project Structure

```
sf-cloud-hub/
├── force-app/
│   └── main/
│       └── default/
│           ├── classes/              # Apex classes
│           ├── lwc/                  # Lightning Web Components
│           ├── objects/              # Custom objects
│           ├── pages/                # Visualforce pages
│           ├── triggers/             # Apex triggers
│           ├── flows/                # Flow definitions
│           ├── staticresources/      # Static resources
│           └── ...
├── config/                           # Configuration files
├── scripts/                          # Deployment scripts
├── sfdx-project.json                # Salesforce project config
├── .gitignore                       # Git ignore rules
└── README.md                        # This file
```

## Getting Started

### Prerequisites
- Salesforce CLI installed: [Install Salesforce CLI](https://developer.salesforce.com/tools/sfdxcli)
- Node.js 14+
- Git

### Installation

1. Clone the repository:
```bash
git clone https://github.com/GouravAnand/sf-cloud-hub.git
cd sf-cloud-hub
```

2. Install dependencies:
```bash
npm install
```

3. Authenticate with your Salesforce org:
```bash
sfdx force:auth:web:login -a myOrg
```

## Deployment

### Deploy to Org
```bash
sfdx force:source:deploy -p force-app --targetusername myOrg
```

### Deploy Specific Metadata
```bash
sfdx force:source:deploy -p force-app/main/default/classes --targetusername myOrg
```

## Contributing

1. Create a feature branch
2. Make your changes
3. Test thoroughly
4. Submit a pull request

## Resources

- [Salesforce Developers](https://developer.salesforce.com)
- [SFDX CLI Documentation](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/)
- [Lightning Web Components](https://developer.salesforce.com/docs/component-library/overview/components)

## License

Proprietary - Salesforce Engineering Repository

---

**Author:** GouravAnand  
**Created:** 2026-10-09
