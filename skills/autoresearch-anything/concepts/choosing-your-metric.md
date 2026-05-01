# Choosing Your Metric

The metric is the single most important decision in your autoresearch pipeline. A bad metric makes the entire system useless. A good metric makes it powerful.

## The Properties Checklist

For autoresearch to work, your optimization target must satisfy ALL of these:

- [ ] **Metric is a single number** - not subjective, not composite. "Reply rate: 2.4%" works. "Overall email quality" doesn't.
- [ ] **Metric is API-accessible** - can be queried programmatically via script or API call. If you have to manually check a dashboard, it can't be automated.
- [ ] **Direction is clear** - higher or lower is better, unambiguous. Reply rate: higher = better. Bounce rate: lower = better.
- [ ] **Measurement is repeatable** - same conditions produce comparable measurements. Same audience type, same volume, same measurement window.
- [ ] **Deployment is automatable** - changes can be deployed via script or API. If you need to manually copy-paste into a UI, this won't work.
- [ ] **Changes are reversible** - can revert to previous state. Git reset + redeploy previous version must work.
- [ ] **Constraints are defined** - you can articulate what must NEVER change between experiments.
- [ ] **Measurement window is appropriate** - enough time for meaningful data to accumulate in one cycle.
- [ ] **Sample size is achievable** - enough volume to meet your minimum threshold within one measurement window.

**If any of these fail, autoresearch is not the right approach for that target.** The Q&A will help surface disqualifiers early.

## Good Metrics (and Why)

| Metric | Direction | Why it works |
|--------|-----------|-------------|
| Reply rate | Higher | Single number, tracked by email platforms, clear direction |
| Conversion rate | Higher | Single number, tracked by analytics tools, universally understood |
| Click-through rate | Higher | Single number, tracked by ad/email platforms, fast feedback |
| Open rate | Higher | Single number, tracked by email platforms, high volume |
| Revenue per visitor | Higher | Single number, calculated from analytics + payment data |
| CSAT score | Higher | Single number (1-10 scale), collected via surveys/APIs |
| Bounce rate | Lower | Single number, tracked by analytics tools |
| Cost per acquisition | Lower | Single number, calculated from ad spend + conversions |

## Bad Metrics (and Why)

| Metric | Problem |
|--------|---------|
| "Brand perception" | Subjective, not a number, no API |
| "Content quality" | Subjective, can't be measured programmatically |
| "Customer happiness" | Too vague, need a proxy (use CSAT instead) |
| "Engagement" | Composite - likes + comments + shares + saves. Pick ONE. |
| "ROI" | Depends on too many variables, measurement window too long |
| Revenue (alone) | Affected by too many confounding variables outside experiment scope |

## The Volume Problem

Even a perfect metric won't work if you don't have enough volume. Autoresearch needs enough data points PER EXPERIMENT to make meaningful comparisons.

Rules of thumb:
- **Cold email**: need at least 100-200 sends per experiment to judge reply rate
- **Landing page**: need at least 200-500 visitors per experiment to judge conversion
- **Ads**: need at least 1000+ impressions per experiment to judge CTR
- **Newsletter**: need at least 500+ subscribers per send to judge open rate

If your measurement window doesn't generate enough volume, either:
1. Increase the measurement window (run each experiment longer)
2. Increase traffic/volume first before starting autoresearch
3. Choose a metric with more data points (e.g., open rate has more data than reply rate)

## Statistical Thresholds

There is no universal "right" threshold. During Q&A setup, you and the agent will determine appropriate thresholds based on:

- **Your data volume**: more data = smaller improvements are detectable
- **Your metric's natural variance**: some metrics are noisier than others
- **Your risk tolerance**: stricter thresholds = fewer false keeps but more missed improvements
- **Your measurement window**: longer windows = more data = more confidence

The threshold is set during setup and written into program.md as a constant. It can be adjusted later by editing program.md.
