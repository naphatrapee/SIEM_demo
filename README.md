# Log Management Demo
Mini SIEM: multi-source ingest -> normalize -> PostgreSQL -> dashboard + alerts. Appliance and SaaS modes.

    make up      # start everything (creates .env from .env.example if missing)
    make seed    # send sample data
    make test    # pytest

See docs/ for architecture and setup.
