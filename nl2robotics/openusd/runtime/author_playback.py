"""Author FMU-derived kinematic time samples onto an OpenUSD stage."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

from pxr import Gf, Usd, UsdGeom


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage", type=Path, required=True)
    parser.add_argument("--trace", type=Path, required=True)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    report = {"success": False, "mappings": []}
    try:
        config = json.loads(args.config.read_text(encoding="utf-8"))
        rows = _read_trace(args.trace)
        stage = Usd.Stage.Open(str(args.stage))
        if stage is None:
            raise ValueError("OpenUSD could not open the source stage")
        clock = config["clock"]
        rate = float(clock["time_codes_per_second"])
        stage.SetStartTimeCode(float(clock["start_time"]) * rate)
        stage.SetEndTimeCode(float(clock["stop_time"]) * rate)
        stage.SetTimeCodesPerSecond(rate)
        stage.SetFramesPerSecond(rate)
        stage.SetInterpolationType(Usd.InterpolationTypeLinear)

        for mapping in config["mappings"]:
            prim = stage.GetPrimAtPath(mapping["usd_driven_prim"])
            if not prim:
                raise ValueError(
                    f"driven prim does not exist: {mapping['usd_driven_prim']}"
                )
            op = _playback_op(
                UsdGeom.Xformable(prim), mapping["joint_type"], mapping["axis"]
            )
            source = mapping["fmu_variable"]
            scale = float(mapping["scale"])
            offset = float(mapping["offset"])
            low = mapping.get("lower_limit")
            high = mapping.get("upper_limit")
            values = []
            for row in rows:
                value = float(row[source]) * scale + offset
                if low is not None and value < float(low) - 1e-9:
                    raise ValueError(f"{source} violates lower joint limit")
                if high is not None and value > float(high) + 1e-9:
                    raise ValueError(f"{source} violates upper joint limit")
                authored = value
                if mapping["joint_type"] == "prismatic":
                    authored = _axis_vector(mapping["axis"], value)
                op.Set(authored, Usd.TimeCode(float(row["time"]) * rate))
                values.append(value)
            report["mappings"].append({
                "id": mapping["id"],
                "attribute": op.GetOpName(),
                "sample_count": len(values),
                "minimum": min(values),
                "maximum": max(values),
            })
        if not stage.GetRootLayer().Export(str(args.output)):
            raise RuntimeError("OpenUSD failed to export the animated stage")
        report.update({
            "success": True,
            "sample_count": len(rows),
            "start_time_code": stage.GetStartTimeCode(),
            "end_time_code": stage.GetEndTimeCode(),
            "time_codes_per_second": stage.GetTimeCodesPerSecond(),
            "interpolation": "linear",
        })
    except Exception as exc:
        report["error"] = f"{type(exc).__name__}: {exc}"
    args.report.write_text(json.dumps(report, indent=2, allow_nan=False), encoding="utf-8")
    return 0 if report["success"] else 1


def _read_trace(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if not rows or "time" not in rows[0]:
        raise ValueError("FMU trace must contain at least one row and a time column")
    return rows


def _playback_op(xformable: UsdGeom.Xformable, joint_type: str,
                 axis: str) -> UsdGeom.XformOp:
    if joint_type == "prismatic":
        expected_name = "xformOp:translate:joint"
        for op in xformable.GetOrderedXformOps():
            if op.GetOpName() == expected_name:
                return op
        return xformable.AddTranslateOp(
            UsdGeom.XformOp.PrecisionDouble, "joint"
        )
    if joint_type != "revolute":
        raise ValueError(f"unsupported playback joint type: {joint_type}")
    expected_name = f"xformOp:rotate{axis}"
    for op in xformable.GetOrderedXformOps():
        if op.GetOpName() == expected_name:
            return op
    if axis == "X":
        return xformable.AddRotateXOp()
    if axis == "Y":
        return xformable.AddRotateYOp()
    if axis == "Z":
        return xformable.AddRotateZOp()
    raise ValueError(f"unsupported rotation axis: {axis}")


def _axis_vector(axis: str, value: float) -> Gf.Vec3d:
    if axis == "X":
        return Gf.Vec3d(value, 0, 0)
    if axis == "Y":
        return Gf.Vec3d(0, value, 0)
    if axis == "Z":
        return Gf.Vec3d(0, 0, value)
    raise ValueError(f"unsupported translation axis: {axis}")


if __name__ == "__main__":
    raise SystemExit(main())
