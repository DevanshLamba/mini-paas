// Shared load scenario: the identical test runs in every environment (local k3d, Azure,
// GitHub Actions) as a Kubernetes Job next to the app, so results compare the clusters
// rather than the network in between.
//
// Three constant-arrival-rate steps (open model: k6 keeps sending at the target rate even
// if the app slows down, so overload shows up as latency, errors and dropped iterations
// instead of being hidden).
import http from 'k6/http';
import { check } from 'k6';

const TARGET = __ENV.TARGET || 'http://sampleapi.sampleapi-dev.svc';
const ITERATIONS = __ENV.WORK_ITERATIONS || '20000'; // ~9 ms of CPU per request on the laptop
const STEP = __ENV.STEP_DURATION || '60s';
const RATES = [20, 60, 120]; // requests per second

const stepSeconds = parseInt(STEP, 10);
const scenarios = {};
const thresholds = {};
RATES.forEach((rate, i) => {
  const name = `rps${rate}`;
  scenarios[name] = {
    executor: 'constant-arrival-rate',
    rate,
    timeUnit: '1s',
    duration: STEP,
    startTime: `${i * stepSeconds}s`,
    preAllocatedVUs: Math.ceil(rate / 2),
    maxVUs: rate * 3,
  };
  // Always-true thresholds: their only purpose is to make k6 report per-step sub-metrics.
  thresholds[`http_req_duration{scenario:${name}}`] = ['max>=0'];
  thresholds[`http_reqs{scenario:${name}}`] = ['count>=0'];
  thresholds[`http_req_failed{scenario:${name}}`] = ['rate>=0'];
  thresholds[`dropped_iterations{scenario:${name}}`] = ['count>=0'];
});

export const options = {
  discardResponseBodies: true,
  summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
  scenarios,
  thresholds,
};

export default function () {
  const res = http.get(`${TARGET}/work?iterations=${ITERATIONS}`, { timeout: '10s' });
  check(res, { 'status is 200': (r) => r.status === 200 });
}

function pick(metric) {
  if (!metric) return null;
  const v = metric.values;
  const r = (x) => (x === undefined ? undefined : Math.round(x * 100) / 100);
  return {
    count: v.count, rate: r(v.rate), avg: r(v.avg), med: r(v.med),
    p90: r(v['p(90)']), p95: r(v['p(95)']), p99: r(v['p(99)']), max: r(v.max),
  };
}

export function handleSummary(data) {
  const m = data.metrics;
  const summary = {
    target: TARGET,
    work_iterations: Number(ITERATIONS),
    step_duration: STEP,
    total: {
      requests: pick(m.http_reqs),
      latency_ms: pick(m.http_req_duration),
      failed_rate: m.http_req_failed ? m.http_req_failed.values.rate : null,
      dropped_iterations: m.dropped_iterations ? m.dropped_iterations.values.count : 0,
    },
    steps: RATES.map((rate) => {
      const s = `scenario:rps${rate}`;
      return {
        target_rps: rate,
        requests: pick(m[`http_reqs{${s}}`]),
        latency_ms: pick(m[`http_req_duration{${s}}`]),
        failed_rate: m[`http_req_failed{${s}}`] ? m[`http_req_failed{${s}}`].values.rate : null,
        dropped_iterations: m[`dropped_iterations{${s}}`] ? m[`dropped_iterations{${s}}`].values.count : 0,
      };
    }),
  };
  return {
    stdout: `\n===K6_SUMMARY_JSON_BEGIN===\n${JSON.stringify(summary)}\n===K6_SUMMARY_JSON_END===\n`,
  };
}
