# KPI definitions (our own proxies, not any company's official metrics)

Write what each metric means, the denominator, and the known weakness. Edit these as you learn the data.

| KPI | Numerator | Denominator | Notes / weakness |
|---|---|---|---|
| On-time delivery % | delivered orders where delivered date <= estimated date | delivered orders | Compared at date level; the estimate has no time of day. |
| Late handoff rate | orders where carrier handoff > shipping_limit_date on any item | single-seller orders | Handoff time is recorded per order, not per seller. |
| Cancellation rate | status = canceled | closed orders (delivered + canceled) | In-flight orders are excluded. |
| Low-review rate | review score 1-2 | orders with a review | Only some orders have reviews; reviewers are self-selected. |
| Order defect rate | closed orders that were canceled OR late OR low-review | closed orders | Our own definition. Say so in the write-up. |
| Promise accuracy | promised days - actual total delivery days | delivered orders | Positive = delivered earlier than promised. Too much padding has a conversion cost we cannot see here. |

## Limitations to state in your write-up
- Seller metrics use single-seller orders only; check how much volume that excludes (see the dq check `multi_seller_orders_excluded_from_seller_metrics`).
- No carrier scan events, so transit is handoff-to-delivery only.
- Reviews and comments are in Portuguese; only a share of reviews have text.
- Public data from one marketplace in one country and period: do not generalize to other marketplaces.
