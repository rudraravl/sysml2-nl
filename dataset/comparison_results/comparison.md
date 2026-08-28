# Naive GLM vs Full Pipeline Comparison

Samples compared: 25

| Condition | Valid % | Mean errors | Median errors | Syntax fail % | Semantic fail % |
|-----------|---------|-------------|---------------|---------------|-----------------|
| Naive GLM (single model) | 0.0 | 110.2 | 83.0 | 100.0 | 100.0 |
| Full pipeline (MoE+refine+kernel+spec) | 20.0 | 31.0 | 17.0 | 52.0 | 64.0 |

## Delta (pipeline - naive)

- Valid rate: +20.0 pp
- Mean errors: -79.2
- Syntax fail rate: -48.0 pp
- Semantic fail rate: -36.0 pp

