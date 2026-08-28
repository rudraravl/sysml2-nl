package NicholsRadiometer {
    import SI::*;
    import ISQ::*;

    // =========================================================================
    // Value Definitions with Units
    // =========================================================================

    value def TorsionalStiffnessValue :> Real {
        :>> unit = "N*m/rad";
    }
    value def MirrorDeflectionAngle :> Angle;
    value def TorsionAngleValue :> Angle;
    value def OpticalLeverArmLength :> Length;
    value def MirrorSurfaceArea :> Area;
    value def VacuumPressureLevel :> Pressure;
    value def ReflectivityValue :> Real;
    value def OpticalScaleDistance :> Length;
    value def RadiationPressureValue :> Pressure;
    value def ForceMagnitudeValue :> Force;
    value def TorqueMagnitudeValue :> Torque;
    value def BeamPowerValue :> Power;
    value def FiberLengthValue :> Length;
    value def FiberDiameterValue :> Length;
    value def ChamberVolumeValue :> Volume;

    // =========================================================================
    // Item Definitions
    // =========================================================================

    item def LightBeam {
        attribute beamPower : BeamPowerValue;
        attribute wavelength : Length;
        attribute crossSectionalArea : MirrorSurfaceArea;
        attribute isEmitting : Boolean;
        doc /* Incident electromagnetic radiation whose momentum transfers pressure to the mirror. */;
    }

    item def ReferenceLaserBeam {
        attribute beamPower : BeamPowerValue;
        attribute wavelength : Length;
        attribute spotDisplacement : Length;
        doc /* Low-power reference laser used by the optical lever to amplify mirror rotation. */;
    }

    // =========================================================================
    // Component Part Definitions
    // =========================================================================

    part def TorsionFiberPart {
        attribute torsionConstant : TorsionalStiffnessValue;
        attribute fiberLength : FiberLengthValue;
        attribute fiberDiameter : FiberDiameterValue;
        attribute dampingCoefficient : Real;
        attribute currentTwist : TorsionAngleValue;
        port topMountPort;
        port mirrorMountPort;
        doc /* Very thin and delicate torsion fiber from which the mirror is suspended; twists under radiation-induced torque and provides a restoring torque proportional to angular deflection. */;
    }

    part def MirrorPart {
        attribute surfaceArea : MirrorSurfaceArea;
        attribute reflectivity : ReflectivityValue;
        attribute leverArm : OpticalLeverArmLength;
        attribute currentAngle : TorsionAngleValue;
        in port incidentLightPort : LightBeam;
        in port incidentLaserPort : ReferenceLaserBeam;
        out port reflectedLaserPort : ReferenceLaserBeam;
        port fiberMountPort;
        doc /* Small, highly reflective vane that receives photon momentum from the incident light beam and reflects the reference laser for the optical lever. */;
    }

    part def VacuumChamberPart {
        attribute internalPressure : VacuumPressureLevel;
        attribute internalVolume : ChamberVolumeValue;
        part fiber : TorsionFiberPart;
        part mirror : MirrorPart;
        in port lightInputPort : LightBeam;
        in port referenceLaserInputPort : ReferenceLaserBeam;
        out port referenceLaserOutputPort : ReferenceLaserBeam;
        port fiberTopAnchorPort;
        connect lightInputPort to mirror.incidentLightPort;
        connect referenceLaserInputPort to mirror.incidentLaserPort;
        connect mirror.reflectedLaserPort to referenceLaserOutputPort;
        connect fiber.mirrorMountPort to mirror.fiberMountPort;
        connect fiber.topMountPort to fiberTopAnchorPort;
        doc /* Evacuated enclosure that eliminates air-current interference so that the minute radiation pressure can be detected above thermal and convective noise. */;
    }

    part def OpticalLaserSourcePart {
        attribute outputPower : BeamPowerValue;
        attribute wavelength : Length;
        out port laserOutputPort : ReferenceLaserBeam;
        doc /* Stable, low-noise reference laser that provides the optical lever beam aimed at the mirror inside the vacuum chamber. */;
    }

    part def OpticalDetectorPart {
        attribute distanceFromMirror : OpticalScaleDistance;
        attribute measuredSpotDisplacement : Length;
        attribute inferredDeflection : MirrorDeflectionAngle;
        in port laserInputPort : ReferenceLaserBeam;
        out port deflectionOutputPort : MirrorDeflectionAngle;
        action readSpotDisplacement {
            doc /* Samples the position of the reflected laser spot on the detector surface and updates measuredSpotDisplacement. */;
        }
        action computeDeflection {
            doc /* Infers the mirror deflection angle from the spot displacement using the optical lever magnification factor: theta = s / (2 * L). */;
        }
        doc /* Position-sensitive detector that measures the amplified laser spot displacement produced by the optical lever and outputs the inferred mirror deflection. */;
    }

    part def RadiationSourcePart {
        attribute outputPower : BeamPowerValue;
        attribute isEmitting : Boolean;
        out port beamOutputPort : LightBeam;
        doc /* Source of the electromagnetic radiation whose pressure is to be measured by the radiometer. */;
    }

    part def ControllerPart {
        attribute measuredDeflection : MirrorDeflectionAngle;
        attribute computedTorque : TorqueMagnitudeValue;
        attribute computedForce : ForceMagnitudeValue;
        attribute computedPressure : RadiationPressureValue;
        in port deflectionInputPort : MirrorDeflectionAngle;
        out port forceOutputPort : ForceMagnitudeValue;
        out port pressureOutputPort : RadiationPressureValue;
        action computeTorque {
            doc /* Computes the restoring torque from the torsion fiber stiffness and the measured deflection: tau = kappa * theta. */;
        }
        action computeForce {
            doc /* Computes the radiation force from the torque and the mirror lever arm: F = tau / d. */;
        }
        action computePressure {
            doc /* Computes the radiation pressure from the force and the mirror surface area: P = F / A. />;
        }
        doc /* Reads the optical lever deflection and, using the known torsion fiber stiffness and mirror geometry, computes the radiation force and pressure. */;
    }

    // =========================================================================
    // Main System Definition
    // =========================================================================

    part def NicholsRadiometerSystem {
        attribute designTorsionConstant : TorsionalStiffnessValue;
        attribute designMirrorArea : MirrorSurfaceArea;
        attribute designLeverArm : OpticalLeverArmLength;
        attribute designScaleDistance : OpticalScaleDistance;
        attribute targetVacuumPressure : VacuumPressureLevel;
        attribute designWavelength : Length;

        part chamber : VacuumChamberPart {
            :>> internalPressure = targetVacuumPressure;
            :>> fiber {
                :>> torsionConstant = designTorsionConstant;
            }
            :>> mirror {
                :>> surfaceArea = designMirrorArea;
                :>> leverArm = designLeverArm;
            }
        }

        part laserSource : OpticalLaserSourcePart {
            :>> wavelength = designWavelength;
        }

        part detector : OpticalDetectorPart {
            :>> distanceFromMirror = designScaleDistance;
        }

        part radiationSource : RadiationSourcePart;
        part controller : ControllerPart;

        // External connections
        connect radiationSource.beamOutputPort to chamber.lightInputPort;
        connect laserSource.laserOutputPort to chamber.referenceLaserInputPort;
        connect chamber.referenceLaserOutputPort to detector.laserInputPort;
        connect detector.deflectionOutputPort to controller.deflectionInputPort;

        // State machine for the operational cycle
        state machine operatingStates {
            state idle {
                doc /* Radiometer is at rest; no light beam is incident on the mirror. The torsion fiber hangs undisturbed at its equilibrium angle. */;
            }

            state measuring {
                doc /* Light beam is active; the radiometer measures the radiation pressure exerted on the mirror. */;
                do {
                    // Optical lever: infer mirror deflection from spot displacement
                    detector.inferredDeflection = detector.measuredSpotDisplacement / (2.0 * detector.distanceFromMirror);
                    controller.measuredDeflection = detector.inferredDeflection;
                    // Torsion fiber restoring torque: tau = kappa * theta
                    controller.computedTorque = designTorsionConstant * controller.measuredDeflection;
                    // Radiation force from torque and lever arm: F = tau / d
                    controller.computedForce = controller.computedTorque / designLeverArm;
                    // Radiation pressure from force and mirror area: P = F / A
                    controller.computedPressure = controller.computedForce / designMirrorArea;
                }
            }

            transition from idle to measuring
                when radiationSource.isEmitting == true;

            transition from measuring to idle
                when radiationSource.isEmitting == false;
        }
    }

    // =========================================================================
    // Requirements
    // =========================================================================

    requirement def MeasureRadiationPressureRequirement {
        doc /* The Nichols radiometer shall measure the radiation pressure exerted by electromagnetic radiation on the mirror surface with high sensitivity. */;
        subject : radiometer : NicholsRadiometerSystem;
        attribute minimumDetectablePressure : RadiationPressureValue;
        attribute measurementUncertainty : Real;
        constraint { minimumDetectablePressure <= 1e-9 [Pa] }
    }

    requirement def VacuumChamberRequirement {
        doc /* The vacuum chamber shall enclose the mirror and fiber assembly and maintain a sufficiently low internal pressure to eliminate air-current interference with the measurement. */;
        subject : chamber : VacuumChamberPart;
        attribute maxInternalPressure : VacuumPressureLevel;
        constraint { chamber.internalPressure <= maxInternalPressure }
        constraint { maxInternalPressure <= 1e-3 [Pa] }
    }

    requirement def TorsionFiberRequirement {
        doc /* The torsion fiber shall provide a small, known torsional stiffness to allow measurement of minute torques produced by radiation pressure. */;
        subject : fiber : TorsionFiberPart;
        attribute maxTorsionConstant : TorsionalStiffnessValue;
        constraint { fiber.torsionConstant <= maxTorsionConstant }
        constraint { maxTorsionConstant <= 1e-6 [N*m/rad] }
    }

    requirement def OpticalLeverRequirement {
        doc /* The optical lever shall amplify the small mirror rotation into a readable displacement on the detector so that the deflection can be measured with sufficient precision. */;
        subject : detector : OpticalDetectorPart;
        attribute minScaleDistance : OpticalScaleDistance;
        constraint { detector.distanceFromMirror >= minScaleDistance }
        constraint { minScaleDistance >= 1 [m] }
    }

    requirement def MirrorReflectivityRequirement {
        doc /* The mirror shall be highly reflective to maximize the radiation pressure transferred to the suspension by the incident photon momentum. */;
        subject : mirror : MirrorPart;
        attribute minReflectivity : ReflectivityValue;
        constraint { mirror.reflectivity >= minReflectivity }
        constraint { minReflectivity >= 0.95 }
    }

    requirement def OperationalCycleRequirement {
        doc /* The radiometer shall operate in an idle state until the light beam is turned on, then transition to a measuring state to determine the radiation pressure, and return to idle when the beam is turned off. */;
        subject : radiometer : NicholsRadiometerSystem;
    }
}
