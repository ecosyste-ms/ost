# Project Scoring

Projects have two independent scores: a general popularity score and a science score.

## Popularity Score

The popularity score measures a project's reach and adoption. It sums five component scores, each calculated using a logarithmic scale to prevent extremely popular projects from dominating. See `app/models/project.rb:1105` for the `update_score` method.

```
score = repository_score + packages_score + commits_score + dependencies_score + events_score
```

The component scores are defined in `score_parts` at `app/models/project.rb:1127`:

**Repository score** (`app/models/project.rb:1137`): `log(stargazers_count + open_issues_count)`

**Packages score** (`app/models/project.rb:1145`): `log(downloads + dependent_packages_count + dependent_repos_count + docker_downloads_count + docker_dependents_count + unique_maintainers)`

**Commits score** (`app/models/project.rb:1157`): `log(total_committers)`

**Dependencies score** (`app/models/project.rb:1164`): Reserved for future use (currently 0)

**Events score** (`app/models/project.rb:1169`): Reserved for future use (currently 0)

The logarithmic scaling means that going from 10 to 100 stars adds roughly the same amount to the score as going from 1,000 to 10,000.

## Science Score

The science score measures how well a project follows academic software practices. It ranges from 0 to 100 and is calculated by `ScienceScoreCalculator` in `app/services/science_score_calculator.rb`.

The Project model calls this via `update_science_score` (`app/models/project.rb:1109`), which persists both the score and a detailed breakdown to the database.

Two scopes filter projects by science score (`app/models/project.rb:50-51`):
- `scientific`: score >= 20
- `highly_scientific`: score >= 75

### JOSS-Published Projects

Projects with JOSS metadata receive a base score of 85, with up to 15 additional points from bonus indicators. This logic is in `calculate_score` at `app/services/science_score_calculator.rb:95`.

| Indicator | Bonus |
|-----------|-------|
| CITATION.cff file | 5 |
| codemeta.json file | 3 |
| .zenodo.json file | 3 |
| DOI in README | 2 |
| Academic committers | 2 |
| Institutional owner | 3 |

### Non-JOSS Projects

Projects without JOSS publication are scored by weighting seven indicators (see `scoring_weights` at `app/services/science_score_calculator.rb:124`):

| Indicator | Weight |
|-----------|--------|
| CITATION.cff file | 22% |
| DOI in README | 17% |
| codemeta.json file | 13% |
| .zenodo.json file | 13% |
| Academic publication links | 13% |
| Academic committers | 13% |
| Institutional owner | 9% |

The final score is the sum of weights for present indicators, normalized to a percentage.

### Indicator Details

Each indicator is checked by a method in `ScienceScoreCalculator`:

**CITATION.cff file** (`app/services/science_score_calculator.rb:153`): The project has a CITATION.cff file, which tells others how to cite the software.

**codemeta.json file** (`app/services/science_score_calculator.rb:161`): The project has a codemeta.json file providing machine-readable software metadata. Detected by checking the repository metadata files.

**.zenodo.json file** (`app/services/science_score_calculator.rb:179`): The project has Zenodo integration configured for archiving releases.

**DOI in README** (`app/services/science_score_calculator.rb:197`): The README contains DOI references matching patterns like `10.xxxx/...` or links to doi.org. The patterns are defined in `DOI_PATTERNS` at line 41.

**Academic publication links** (`app/services/science_score_calculator.rb:236`): The README links to academic sites. The `ACADEMIC_LINK_PATTERNS` constant (line 47) includes arXiv, bioRxiv, PubMed, Nature, Science, IEEE, ACM, PLOS, Springer, Wiley, Zenodo, and others.

**Academic committers** (`app/services/science_score_calculator.rb:256`): At least one committer has an email from an academic domain. The `ACADEMIC_DOMAINS` constant (line 4) includes .edu, .ac.uk, university research labs, national laboratories (NASA, NIH, NIST, ORNL, etc.), and major research institutions (CERN, Max Planck, Fraunhofer, INRIA, etc.).

**Institutional owner** (`app/services/science_score_calculator.rb:288`): The repository owner is an organization with a website on an academic domain. Only applies to organization-owned repositories, not personal accounts.

**JOSS paper** (`app/services/science_score_calculator.rb:320`): The project has been published in the Journal of Open Source Software. Detected via the `joss_metadata` field on the project.

### Score Ranges

- 0-20: Low scientific indicators
- 20-40: Some scientific practices
- 40-60: Moderate scientific practices
- 60-80: Strong scientific practices
- 80-100: Excellent scientific practices (typically JOSS-published or equivalent)
