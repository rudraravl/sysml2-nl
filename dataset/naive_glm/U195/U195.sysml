package AdjustableUnderarmCrutchModel {
    import ScalarValues::*;

    package Quantities {
        dimension length :> Real;
        dimension mass :> Real;
        dimension force :> Real;
        dimension pressure :> Real;
        dimension area :> Real;
        dimension angle :> Real;
        dimension dimensionlessRatio :> Real;
        dimension frequency :> Real;

        unit mm :> length;
        unit cm :> length;
        unit m :> length;
        unit g :> mass;
        unit kg :> mass;
        unit N :> force;
        unit kN :> force;
        unit Pa :> pressure;
        unit MPa :> pressure;
        unit cm2 :> area;
        unit mm2 :> area;
        unit deg :> angle;
        unit rad :> angle;
        unit Hz :> frequency;
    }

    package ValueTypes {
        import Quantities::*;

        value type CrutchHeight :> length;
        value type ShaftLength :> length;
        value type ComponentDiameter :> length;
        value type WallThickness :> length;
        value type PinDiameterValue :> length;
        value type PaddingThicknessValue :> length;
        value type CuffWidthValue :> length;
        value type GripDiameterValue :> length;
        value type FootDiameterValue :> length;
        value type HoleSpacingValue :> length;
        value type GripLengthValue :> length;

        value type ComponentMassValue :> mass;
        value type TotalMassValue :> mass;

        value type AppliedLoadValue :> force;
        value type LoadCapacityValue :> force;
        value type YieldStrengthValue :> force;
        value type TensileStrengthValue :> force;

        value type FrictionCoefficientValue :> dimensionlessRatio;
        value type SafetyFactorValue :> dimensionlessRatio;

        value type ContactPressureValue :> pressure;
        value type ContactAreaValue :> area;

        value type CuffCurvatureValue :> angle;
        value type GripAngleValue :> angle;
        value type TreadPatternAngleValue :> angle;
        value type LateralDeviationAngleValue :> angle;

        value type CycleFrequencyValue :> frequency;
    }

    package Materials {
        import ValueTypes::*;

        value type StructuralMaterial {
            attribute name : String;
            attribute density : Real;
            attribute yieldStrength : YieldStrengthValue;
            attribute tensileStrength : TensileStrengthValue;
            attribute isLightweight : Boolean;
            attribute isCorrosionResistant : Boolean;
        }

        value type PaddingMaterialType {
            attribute name : String;
            attribute shoreHardness : Real;
            attribute density : Real;
            attribute isHypoallergenic : Boolean;
        }

        value type GripMaterialType {
            attribute name : String;
            attribute surfaceFrictionCoefficient : FrictionCoefficientValue;
            attribute isAntimicrobial : Boolean;
        }

        value type RubberCompoundType {
            attribute name : String;
            attribute shoreHardness : Real;
            attribute baseFrictionCoefficient : FrictionCoefficientValue;
            attribute operatingTemperatureRange : String;
        }

        attribute aluminum7075 : StructuralMaterial = StructuralMaterial {
            name = "Aluminum 7075-T6";
            density = 2.81;
            yieldStrength = 5030 [N];
            tensileStrength = 5700 [N];
            isLightweight = true;
            isCorrosionResistant = true;
        };

        attribute stainlessSteel316 : StructuralMaterial = StructuralMaterial {
            name = "Stainless Steel 316";
            density = 7.99;
            yieldStrength = 29000 [N];
            tensileStrength = 58000 [N];
            isLightweight = false;
            isCorrosionResistant = true;
        };

        attribute reinforcedPolymer : StructuralMaterial = StructuralMaterial {
            name = "Reinforced polymer composite";
            density = 1.45;
            yieldStrength = 3000 [N];
            tensileStrength = 3500 [N];
            isLightweight = true;
            isCorrosionResistant = true;
        };

        attribute hdpeFoam : PaddingMaterialType = PaddingMaterialType {
            name = "High-density polyethylene foam";
            shoreHardness = 55;
            density = 0.035;
            isHypoallergenic = true;
        };

        attribute medicalGradeElastomer : GripMaterialType = GripMaterialType {
            name = "Medical-grade elastomer";
            surfaceFrictionCoefficient = 0.85;
            isAntimicrobial = true;
        };

        attribute naturalRubberCompound : RubberCompoundType = RubberCompoundType {
            name = "Natural rubber compound";
            shoreHardness = 65;
            baseFrictionCoefficient = 0.85;
            operatingTemperatureRange = "-20 to 60 Celsius";
        };
    }

    package Events {
        item def HeightAdjustmentInitiated;
        item def LockEngaged;
        item def UserWeightApplied;
        item def UserWeightRemoved;
        item def StoreCrutch;
        item def InspectionRequested;
        item def MaintenanceCompleted;
    }

    package Ports {
        import ValueTypes::*;

        port def LoadTransferPort {
            attribute loadMagnitude : AppliedLoadValue;
            in loadRequest : AppliedLoadValue;
            out loadResponse : AppliedLoadValue;
        }

        port def GroundContactPort {
            attribute normalForce : AppliedLoadValue;
            attribute lateralForce : AppliedLoadValue;
            attribute frictionCoefficient : FrictionCoefficientValue;
            attribute contactArea : ContactAreaValue;
            in appliedVerticalLoad : AppliedLoadValue;
            out tractionForce : AppliedLoadValue;
            out reactionForce : AppliedLoadValue;
        }

        port def UserContactPort {
            attribute distributedPressure : ContactPressureValue;
            attribute contactArea : ContactAreaValue;
            in userWeightInput : AppliedLoadValue;
            out pressureDistribution : ContactPressureValue;
        }

        port def AdjustmentInterfacePort {
            attribute currentHeight : CrutchHeight;
            attribute targetHeight : CrutchHeight;
            in heightCommand : CrutchHeight;
            out heightStatus : CrutchHeight;
            in lockCommand : Boolean;
            out lockStatus : Boolean;
        }

        port def MaintenancePort {
            attribute componentHealth : Real;
            in inspectionRequest : Boolean;
            out inspectionReport : String;
        }
    }

    package Components {
        import ValueTypes::*;
        import Materials::*;
        import Ports::*;

        part def TelescopicShaft {
            attribute material : StructuralMaterial;
            attribute collapsedLength : ShaftLength;
            attribute maximumLength : ShaftLength;
            attribute extendedLength : ShaftLength;
            attribute outerTubeDiameter : ComponentDiameter;
            attribute innerTubeDiameter : ComponentDiameter;
            attribute wallThickness : WallThickness;
            attribute mass : ComponentMassValue;
            attribute isStructurallySound : Boolean = true;

            port upperLoad : LoadTransferPort;
            port lowerLoad : LoadTransferPort;
            port adjustment : AdjustmentInterfacePort;

            action def adjustLength {
                in targetLength : ShaftLength;
                out resultingLength : ShaftLength;
            }
            action def lockAtPosition;
            action def verifyStructuralIntegrity {
                out isSound : Boolean;
            }
        }

        part def HeightLockMechanism {
            attribute pinMaterial : StructuralMaterial;
            attribute pinDiameter : PinDiameterValue;
            attribute adjustmentHoleCount : Integer;
            attribute holeSpacing : HoleSpacingValue;
            attribute lockState : String = "unlocked";
            attribute currentPinPosition : Integer = 0;
            attribute isLockSecure : Boolean = false;

            port adjustment : AdjustmentInterfacePort;

            action def engagePin {
                in position : Integer;
                out lockStatus : String;
                out isSecure : Boolean;
            }
            action def disengagePin;
            action def verifyLockIntegrity {
                out isSecure : Boolean;
            }
        }

        part def UnderarmCuff {
            attribute paddingMaterial : PaddingMaterialType;
            attribute cuffFrameMaterial : StructuralMaterial;
            attribute paddingThickness : PaddingThicknessValue;
            attribute cuffWidth : CuffWidthValue;
            attribute cuffCurvature : CuffCurvatureValue;
            attribute contactArea : ContactAreaValue;
            attribute mass : ComponentMassValue;

            port userInterface : UserContactPort;
            port shaftMount : LoadTransferPort;

            action def distributeLoad {
                in appliedLoad : AppliedLoadValue;
                out distributedPressure : ContactPressureValue;
            }
        }

        part def HandGrip {
            attribute gripMaterial : GripMaterialType;
            attribute gripAngle : GripAngleValue;
            attribute gripDiameter : GripDiameterValue;
            attribute gripLength : GripLengthValue;
            attribute surfaceTexture : String;
            attribute mass : ComponentMassValue;

            port userInterface : UserContactPort;
            port shaftMount : LoadTransferPort;

            action def transmitGripForce {
                in gripForce : AppliedLoadValue;
                out shaftForce : AppliedLoadValue;
            }
        }

        part def RubberFootTip {
            attribute rubber : RubberCompoundType;
            attribute treadPattern : String;
            attribute treadPatternAngle : TreadPatternAngleValue;
            attribute contactDiameter : FootDiameterValue;
            attribute baseDiameter : FootDiameterValue;
            attribute contactArea : ContactAreaValue;
            attribute coefficientOfFriction : FrictionCoefficientValue;
            attribute mass : ComponentMassValue;
            attribute wearLevel : Real = 0.0;
            attribute wearReplacementThreshold : Real = 0.7;

            port shaftMount : LoadTransferPort;
            port groundInterface : GroundContactPort;

            action def absorbShock {
                in impactForce : AppliedLoadValue;
                out dampenedForce : AppliedLoadValue;
            }
            action def provideTraction {
                in normalForce : AppliedLoadValue;
                out tractionForce : AppliedLoadValue;
            }
            action def inspectWear {
                out wearLevelReading : Real;
                out requiresReplacement : Boolean;
            }
        }
    }

    package Assembly {
        import Components::*;
        import ValueTypes::*;
        import Ports::*;
        import Events::*;
        import Materials::*;

        part def AdjustableUnderarmCrutch {
            attribute manufacturer : String;
            attribute model : String;
            attribute serialNumber : String;
            attribute totalMass : TotalMassValue;
            attribute maxUserWeight : LoadCapacityValue;
            attribute currentHeight : CrutchHeight;
            attribute currentLoad : AppliedLoadValue = 0 [N];
            attribute userHeightRange : String;
            attribute inspectionComplete : Boolean = false;
            attribute isStable : Boolean = true;

            part telescopicShaft : TelescopicShaft {
                attribute material = aluminum7075;
                attribute collapsedLength = 700 [mm];
                attribute maximumLength = 1100 [mm];
                attribute extendedLength = 950 [mm];
                attribute outerTubeDiameter = 25 [mm];
                attribute innerTubeDiameter = 22 [mm];
                attribute wallThickness = 1.5 [mm];
                attribute mass = 450 [g];
            }

            part heightLock : HeightLockMechanism {
                attribute pinMaterial = stainlessSteel316;
                attribute pinDiameter = 5 [mm];
                attribute adjustmentHoleCount = 8;
                attribute holeSpacing = 50 [mm];
            }

            part cuff : UnderarmCuff {
                attribute paddingMaterial = hdpeFoam;
                attribute cuffFrameMaterial = reinforcedPolymer;
                attribute paddingThickness = 15 [mm];
                attribute cuffWidth = 100 [mm];
                attribute cuffCurvature = 160 [deg];
                attribute contactArea = 80 [cm2];
                attribute mass = 220 [g];
            }

            part grip : HandGrip {
                attribute gripMaterial = medicalGradeElastomer;
                attribute gripAngle = 12 [deg];
                attribute gripDiameter = 35 [mm];
                attribute gripLength = 110 [mm];
                attribute surfaceTexture = "Ergonomic contoured";
                attribute mass = 120 [g];
            }

            part footTip : RubberFootTip {
                attribute rubber = naturalRubberCompound;
                attribute treadPattern = "Multi-directional high-friction tread";
                attribute treadPatternAngle = 45 [deg];
                attribute contactDiameter = 40 [mm];
                attribute baseDiameter = 32 [mm];
                attribute contactArea = 12.6 [cm2];
                attribute coefficientOfFriction = 0.85;
                attribute mass = 85 [g];
            }

            port userInterface : UserContactPort;
            port groundInterface : GroundContactPort;
            port maintenance : MaintenancePort;

            connection cuffShaftLink connect cuff.shaftMount to telescopicShaft.upperLoad;
            connection gripShaftLink connect grip.shaftMount to telescopicShaft.upperLoad;
            connection lockShaftLink connect heightLock.adjustment to telescopicShaft.adjustment;
            connection shaftFootLink connect telescopicShaft.lowerLoad to footTip.shaftMount;
            connection userLoadPath connect userInterface to cuff.userInterface;
            connection userGripPath connect userInterface to grip.userInterface;
            connection groundContactPath connect groundInterface to footTip.groundInterface;

            state machine CrutchLifecycle {
                state Storage {
                    entry action enterStorageMode;
                }

                state Configuration {
                    entry action beginConfiguration;
                    do action performHeightAdjustment;
                    exit action finalizeConfiguration;
                }

                state Ready {
                    entry action enterReadyMode;
                }

                state ActiveSupport {
                    entry action beginWeightBearing;
                    do action sustainWeightSupport;
                    exit action releaseWeightSupport;
                }

                state Maintenance {
                    entry action beginMaintenance;
                    do action performComponentInspection;
                    exit action finalizeMaintenance;
                }

                transition t_storage_to_config
                    from Storage to Configuration
                    trigger HeightAdjustmentInitiated;

                transition t_config_to_ready
                    from Configuration to Ready
                    guard heightLock.isLockSecure == true
                    trigger LockEngaged;

                transition t_ready_to_active
                    from Ready to ActiveSupport
                    trigger UserWeightApplied;

                transition t_active_to_ready
                    from ActiveSupport to Ready
                    guard currentLoad == 0 [N]
                    trigger UserWeightRemoved;

                transition t_ready_to_storage
                    from Ready to Storage
                    trigger StoreCrutch;

                transition t_storage_to_maintenance
                    from Storage to Maintenance
                    trigger InspectionRequested;

                transition t_maintenance_to_storage
                    from Maintenance to Storage
                    guard inspectionComplete == true
                    trigger MaintenanceCompleted;
            }
        }
    }

    package Requirements {
        import Assembly::*;
        import ValueTypes::*;
        import Components::*;

        requirement def LoadCapacityRequirement {
            subject crutch : AdjustableUnderarmCrutch;
            attribute minimumLoadCapacity : LoadCapacityValue = 1200 [N];
            attribute designSafetyFactor : SafetyFactorValue = 3.0;
            constraint { crutch.maxUserWeight >= minimumLoadCapacity }
            constraint { crutch.telescopicShaft.material.yieldStrength >= crutch.maxUserWeight * designSafetyFactor }
        }

        requirement def StructuralIntegrityRequirement {
            subject crutch : AdjustableUnderarmCrutch;
            attribute minimumYieldStrength : YieldStrengthValue = 3600 [N];
            attribute minimumWallThickness : WallThickness = 1.5 [mm];
            constraint { crutch.telescopicShaft.material.yieldStrength >= minimumYieldStrength }
            constraint { crutch.telescopicShaft.wallThickness >= minimumWallThickness }
        }

        requirement def GroundTractionRequirement {
            subject footTip : RubberFootTip;
            attribute minimumFrictionCoefficient : FrictionCoefficientValue = 0.6;
            attribute minimumContactArea : ContactAreaValue = 10 [cm2];
            constraint { footTip.coefficientOfFriction >= minimumFrictionCoefficient }
            constraint { footTip.contactArea >= minimumContactArea }
        }

        requirement def LightweightDesignRequirement {
            subject crutch : AdjustableUnderarmCrutch;
            attribute maximumTotalMass : TotalMassValue = 1.2 [kg];
            constraint { crutch.totalMass <= maximumTotalMass }
        }

        requirement def HeightAdjustabilityRequirement {
            subject crutch : AdjustableUnderarmCrutch;
            attribute minimumHeight : CrutchHeight = 750 [mm];
            attribute maximumHeight : CrutchHeight = 1100 [mm];
            attribute minimumPositions : Integer = 8;
            constraint { crutch.currentHeight >= minimumHeight and crutch.currentHeight <= maximumHeight }
            constraint { crutch.heightLock.adjustmentHoleCount >= minimumPositions }
        }

        requirement def UserComfortRequirement {
            subject crutch : AdjustableUnderarmCrutch;
            attribute maximumCuffPressure : ContactPressureValue = 40000 [Pa];
            attribute minimumGripDiameter : GripDiameterValue = 30 [mm];
            constraint { crutch.cuff.paddingMaterial.isHypoallergenic == true }
            constraint { crutch.grip.gripDiameter >= minimumGripDiameter }
        }

        requirement def StabilityRequirement {
            subject crutch : AdjustableUnderarmCrutch;
            attribute maximumLateralDeviation : LateralDeviationAngleValue = 5 [deg];
            attribute minimumBaseDiameter : FootDiameterValue = 30 [mm];
            constraint { crutch.footTip.baseDiameter >= minimumBaseDiameter }
        }

        requirement def MaintenanceAccessibilityRequirement {
            subject crutch : AdjustableUnderarmCrutch;
            attribute inspectionIntervalDays : Integer = 180;
            constraint { crutch.isStable == true }
        }

        requirement loadCapacityReq : LoadCapacityRequirement;
        requirement structuralReq : StructuralIntegrityRequirement;
        requirement tractionReq : GroundTractionRequirement;
        requirement weightReq : LightweightDesignRequirement;
        requirement adjustabilityReq : HeightAdjustabilityRequirement;
        requirement comfortReq : UserComfortRequirement;
        requirement stabilityReq : StabilityRequirement;
        requirement maintenanceReq : MaintenanceAccessibilityRequirement;

        part crutchInstance : AdjustableUnderarmCrutch {
            attribute manufacturer = "MobilityAssist Inc.";
            attribute model = "AUC-1000";
            attribute serialNumber = "SN-2024-0001";
            attribute totalMass = 0.875 [kg];
            attribute maxUserWeight = 1200 [N];
            attribute currentHeight = 950 [mm];
            attribute userHeightRange = "150-195 cm";
        }

        satisfy loadCapacityReq by crutchInstance;
        satisfy structuralReq by crutchInstance;
        satisfy tractionReq by crutchInstance.footTip;
        satisfy weightReq by crutchInstance;
        satisfy adjustabilityReq by crutchInstance;
        satisfy comfortReq by crutchInstance;
        satisfy stabilityReq by crutchInstance;
        satisfy maintenanceReq by crutchInstance;
    }
}
