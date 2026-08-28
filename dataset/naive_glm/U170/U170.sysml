package BodokSealGasConnectionSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types ----
    item def PressureValue :> Real { attribute unit : String = "bar"; }
    item def TorqueValue :> Real { attribute unit : String = "N*m"; }
    item def LeakRateValue :> Real { attribute unit : String = "mL/min"; }
    item def ForceValue :> Real { attribute unit : String = "N"; }
    item def LengthValue :> Real { attribute unit : String = "mm"; }
    item def CycleCount :> Integer;
    item def RoughnessValue :> Real { attribute unit : String = "um"; }

    // ---- Enumerations ----
    enum def SealLifecycleState {
        positioned;
        compressed;
        sealed;
        pressurized;
        degrading;
        failed;
    }

    enum def ValvePosition { open; closed; }

    // ---- Items ----
    item def MedicalGas {
        attribute name : String;
        attribute maxServicePressure : PressureValue;
    }

    item OxygenGas : MedicalGas {
        name = "Oxygen";
        maxServicePressure = 200;
    }

    // ---- Port Definitions ----
    port def HighPressureGasPort {
        attribute pressure : PressureValue;
        out item gas : MedicalGas;
    }

    port def SealingFacePort {
        attribute surfaceRoughness : RoughnessValue;
        attribute flatnessTolerance : LengthValue;
        attribute faceDiameter : LengthValue;
    }

    // ---- Component Parts ----
    part def NylonWasher {
        attribute material : String = "Nylon";
        attribute shoreHardness : Real;
        attribute initialThickness : LengthValue = 1.5;
        attribute deformedThickness : LengthValue;
        attribute maxCycles : CycleCount = 100;
        attribute currentCycles : CycleCount = 0;
        attribute deformationLimit : LengthValue = 0.8;

        action def deform {
            in compressionForce : ForceValue;
            out resultingThickness : LengthValue;
            out deformationComplete : Boolean;
        }

        action def resetDeformation {
            out restoredThickness : LengthValue;
        }
    }

    part def BrassRetainingRing {
        attribute material : String = "Brass";
        attribute innerDiameter : LengthValue;
        attribute outerDiameter : LengthValue;
        attribute ringThickness : LengthValue;
        attribute yieldStrength : PressureValue;
    }

    part def BodokSealAssembly {
        part washer : NylonWasher;
        part retainingRing : BrassRetainingRing;

        attribute maxServicePressure : PressureValue = 200;
        attribute maxAllowableLeakRate : LeakRateValue = 0.5;
        attribute isReusable : Boolean = true;
        attribute sealIntegrity : Boolean = false;
        attribute compressionForce : ForceValue;

        port sealingFace : SealingFacePort;

        action def compress {
            in appliedTorque : TorqueValue;
            out sealAchieved : Boolean;
            out deformationComplete : Boolean;
        }

        action def release {
            out sealBroken : Boolean;
        }

        action def inspect {
            out integrityStatus : Boolean;
            out remainingCycles : CycleCount;
        }
    }

    part def CylinderValveOutlet {
        attribute maxPressure : PressureValue = 200;
        attribute sealingFaceRoughness : RoughnessValue = 0.8;
        attribute valvePosition : ValvePosition = ValvePosition::closed;

        port gasOutlet : HighPressureGasPort;
        port flatSealingFace : SealingFacePort;

        action def openValve {
            out position : ValvePosition;
        }

        action def closeValve {
            out position : ValvePosition;
        }
    }

    part def RegulatorInlet {
        attribute inletPressureRating : PressureValue = 200;
        attribute outletPressure : PressureValue;
        attribute sealingFaceRoughness : RoughnessValue = 0.8;

        port gasInlet : HighPressureGasPort;
        port flatSealingFace : SealingFacePort;

        action def regulatePressure {
            in inletPressure : PressureValue;
            out regulatedPressure : PressureValue;
        }
    }

    part def ConnectionNut {
        attribute threadSize : String = "G5/8";
        attribute material : String = "Brass";
        attribute appliedTorque : TorqueValue = 0;
        attribute targetTorque : TorqueValue = 25;
        attribute torqueTolerance : TorqueValue = 2;

        action def tighten {
            in targetTorque : TorqueValue;
            out appliedTorque : TorqueValue;
            out torqueAchieved : Boolean;
        }

        action def loosen {
            out released : Boolean;
        }
    }

    part def PressureSensor {
        attribute measuredPressure : PressureValue = 0;
        attribute measuredLeakRate : LeakRateValue = 0;
        attribute thresholdLeakRate : LeakRateValue = 0.5;
        attribute criticalLeakRate : LeakRateValue = 5.0;
        attribute isFunctional : Boolean = true;

        action def measure {
            out pressure : PressureValue;
            out leakRate : LeakRateValue;
        }

        action def detectLeak {
            out leakDetected : Boolean;
            out severityLevel : Integer;
        }
    }

    part def BodokSealGasConnectionSystem {
        part cylinderValveOutlet : CylinderValveOutlet;
        part regulatorInlet : RegulatorInlet;
        part bodokSeal : BodokSealAssembly;
        part connectionNut : ConnectionNut;
        part pressureSensor : PressureSensor;

        attribute systemPressure : PressureValue = 0;
        attribute sealIntegrity : Boolean = false;
        attribute connectionCycles : CycleCount = 0;
        attribute currentLifecycleState : SealLifecycleState = SealLifecycleState::positioned;

        connection connectValveToSeal : cylinderValveOutlet.flatSealingFace to bodokSeal.sealingFace;
        connection connectSealToRegulator : bodokSeal.sealingFace to regulatorInlet.flatSealingFace;
        connection connectGasFlow : cylinderValveOutlet.gasOutlet to regulatorInlet.gasInlet;

        state machine def SealLifecycle {
            initial state Positioned;
            state Compressed;
            state Sealed;
            state Pressurized;
            state Degrading;
            state Failed;

            transition Positioned to Compressed
                when connectionNut.appliedTorque > 0;

            transition Compressed to Sealed
                when bodokSeal.sealIntegrity == true;

            transition Sealed to Pressurized
                when systemPressure > 0;

            transition Pressurized to Degrading
                when pressureSensor.measuredLeakRate > pressureSensor.thresholdLeakRate;

            transition Degrading to Failed
                when pressureSensor.measuredLeakRate > pressureSensor.criticalLeakRate;

            transition Failed to Positioned
                when connectionCycles < bodokSeal.washer.maxCycles
                and bodokSeal.isReusable == true;

            transition Degrading to Sealed
                when pressureSensor.measuredLeakRate <= pressureSensor.thresholdLeakRate;
        }

        action def establishSeal {
            in targetTorque : TorqueValue;
            out sealAchieved : Boolean;

            action tightenNut : connectionNut.tighten {
                in targetTorque = targetTorque;
                out appliedTorque;
                out torqueAchieved;
            }

            action compressSeal : bodokSeal.compress {
                in appliedTorque = tightenNut.appliedTorque;
                out sealAchieved = sealAchieved;
                out deformationComplete;
            }

            then assign sealIntegrity := compressSeal.sealAchieved;
            then assign currentLifecycleState := SealLifecycleState::sealed;
        }

        action def pressurizeSystem {
            in gas : MedicalGas;
            in targetPressure : PressureValue;

            action openValveAction : cylinderValveOutlet.openValve {
                out position;
            }

            action regulateAction : regulatorInlet.regulatePressure {
                in inletPressure = targetPressure;
                out regulatedPressure;
            }

            then assign systemPressure := targetPressure;
            then assign currentLifecycleState := SealLifecycleState::pressurized;
        }

        action def monitorPerformance {
            out pressure : PressureValue;
            out leakRate : LeakRateValue;
            out integrity : Boolean;

            action measureAction : pressureSensor.measure {
                out pressure;
                out leakRate;
            }

            action leakDetectAction : pressureSensor.detectLeak {
                out leakDetected;
                out severityLevel;
            }

            then assign integrity := not leakDetectAction.leakDetected;
            then assign sealIntegrity := integrity;
        }

        action def disconnect {
            out released : Boolean;

            action closeValveAction : cylinderValveOutlet.closeValve {
                out position;
            }

            action loosenNutAction : connectionNut.loosen {
                out released;
            }

            action releaseSealAction : bodokSeal.release {
                out sealBroken;
            }

            then assign systemPressure := 0;
            then assign sealIntegrity := false;
            then assign connectionCycles := connectionCycles + 1;
            then assign currentLifecycleState := SealLifecycleState::positioned;
        }

        action def inspectSeal {
            out integrityStatus : Boolean;
            out remainingCycles : CycleCount;

            action inspectAction : bodokSeal.inspect {
                out integrityStatus;
                out remainingCycles;
            }
        }
    }

    // ---- Requirements ----
    requirement def HighPressureSealingRequirement {
        doc "The Bodok seal system shall maintain a leak-tight seal at service pressures up to 200 bar.";
        attribute maxServicePressure : PressureValue = 200;
        attribute maxLeakRate : LeakRateValue = 0.5;
        subject sealSystem : BodokSealGasConnectionSystem;

        require sealSystem.systemPressure <= maxServicePressure;
        require sealSystem.pressureSensor.measuredLeakRate <= maxLeakRate;
    }

    requirement def ReusabilityRequirement {
        doc "The Bodok seal shall be reusable for multiple connection cycles before replacement.";
        attribute minCycles : CycleCount = 50;
        subject seal : BodokSealAssembly;

        require seal.washer.maxCycles >= minCycles;
        require seal.isReusable == true;
    }

    requirement def TorqueControlledCompressionRequirement {
        doc "The connection nut shall be tightened to a specified torque to achieve controlled compression of the Bodok seal.";
        attribute targetTorque : TorqueValue = 25;
        attribute tolerance : TorqueValue = 2;
        subject nut : ConnectionNut;

        require nut.appliedTorque >= targetTorque - tolerance;
        require nut.appliedTorque <= targetTorque + tolerance;
    }

    requirement def LeakIntegrityMonitoringRequirement {
        doc "The system shall continuously monitor seal integrity to ensure safe gas delivery.";
        subject monitor : PressureSensor;

        require monitor.isFunctional == true;
        require monitor.thresholdLeakRate <= 0.5;
    }

    requirement def MaterialCompositionRequirement {
        doc "The Bodok seal shall consist of a nylon washer held within a brass retaining ring.";
        subject seal : BodokSealAssembly;

        require seal.washer.material == "Nylon";
        require seal.retainingRing.material == "Brass";
    }

    requirement def LifecycleManagementRequirement {
        doc "The system shall track the seal lifecycle from positioning through failure and support reconnection when reusable.";
        subject sealSystem : BodokSealGasConnectionSystem;

        require sealSystem.currentLifecycleState == SealLifecycleState::sealed
            or sealSystem.currentLifecycleState == SealLifecycleState::pressurized
            implies sealSystem.sealIntegrity == true;
    }

    // ---- Requirement Satisfaction ----
    satisfaction HighPressureSealingRequirement by BodokSealGasConnectionSystem;
    satisfaction ReusabilityRequirement by BodokSealAssembly;
    satisfaction TorqueControlledCompressionRequirement by ConnectionNut;
    satisfaction LeakIntegrityMonitoringRequirement by PressureSensor;
    satisfaction MaterialCompositionRequirement by BodokSealAssembly;
    satisfaction LifecycleManagementRequirement by BodokSealGasConnectionSystem;
}
