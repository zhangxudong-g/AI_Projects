# Repository Guidelines

## Project Structure & Module Organization
- `cli/`: core pipeline scripts and stage YAMLs (`run_single_case_pipeline.py`, `run_multi_cases_unified.py`). Treat this as the source of truth for scoring logic.
- `backend/`: FastAPI app (`main.py`), routers, and service layer that wraps the CLI pipeline.
- `frontend/`: React + TypeScript UI (pages, components, API client).
- `data/`: case inputs, plans, reports, and `output/` artifacts.
- SQLite database files live locally (for example `judge.db`), and are used for API-backed storage.

## Build, Test, and Development Commands
- `pip install -r requirements.txt`: install backend dependencies.
- `cd backend; uvicorn main:app --reload --port 8000`: run the API for local dev.
- `cd frontend; npm install`: install frontend dependencies.
- `cd frontend; npm start`: run the React dev server.
- `cd frontend; npm run build`: produce a production build.
- `python cli/run_single_case_pipeline.py --case-id <id>`: run one evaluation case.
- `python cli/run_multi_cases_unified.py <all|resume|retry> --cases <file> --output <dir>`: run batch evaluations.
- `python run_stage2_regression.py`: run regression checks for stage 2.

## Coding Style & Naming Conventions
- Python: 4-space indentation, `snake_case` for functions/variables, `PascalCase` for classes.
- TypeScript/React: 2-space indentation, `PascalCase` components, `camelCase` hooks/functions.
- Follow existing module boundaries: business logic in `backend/services`, API wiring in `backend/routers`, UI API calls in `frontend/src/api`.
- Frontend linting relies on the `react-app` ESLint configuration.

## Testing Guidelines
- Backend tests use `pytest`; frontend tests use Jest + React Testing Library.
- Repository-root `test_*.py` files are integration/system checks; run them with `python <file>.py` as needed.
- Keep test names descriptive and colocate new unit tests near the feature layer they cover.

## Commit & Pull Request Guidelines
- Commit messages follow a conventional prefix (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`) based on recent history.
- PRs should include: a concise summary, test commands run, and UI screenshots when frontend changes are involved.
- Do not change the CLI pipeline behavior unless the PR explicitly targets CLI logic; the web layer should remain a wrapper over `cli/`.

## Configuration Notes
- Frontend reads `REACT_APP_API_URL` (defaults to `http://localhost:8000`).
- Keep local artifacts under `data/output/` to avoid mixing generated files with source.
