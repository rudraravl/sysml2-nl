package ScrollCompressorSystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure :> Real {
        unit = "Pa";
    }

    attribute def Temperature :> Real {
        unit = "K";
    }

    attribute def MassFlowRate :> Real {
        unit = "kg/s";
    }

    attribute def RotationalSpeed :> Real {
        unit = "rpm";
    }

    attribute def Power :> Real {
        unit = "W";
    }

    attribute def Torque :> Real {
        unit = "N*m";
    }

    attribute def VolumeFlowRate :> Real {
        unit = "m^3/s";
    }

    attribute def Efficiency :> Real {
        unit = "1";
    }

    item def Refrigerant {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute massFlow : MassFlowRate;
        attribute quality : Real;
    }

    item def ElectricalPower {
        attribute voltage : Real;
        attribute current : Real;
        attribute frequency : Real;
        attribute realPower : Power;
    }

    item def MechanicalPower {
        attribute shaftSpeed : RotationalSpeed;
        attribute shaftTorque : Torque;
        attribute transmittedPower : Power;
    }

    port def RefrigerantPort {
        inout item fluid : Refrigerant;
    }

    port def ElectricalPort {
        in item supply : ElectricalPower;
    }

    port def MechanicalPort {
        inout item rotation : MechanicalPower;
    }

    port def ThermalPort {
        out attribute heatRejected : Power;
        out attribute casingTemperature : Temperature;
    }

    part def ScrollCompressorSystem {
        doc /* Primary function: receive low-pressure refrigerant vapor and electrical power, convert electrical power into orbiting scroll motion, trap and reduce refrigerant pocket volume between fixed and orbiting scrolls, and discharge high-pressure refrigerant vapor for a refrigeration or heat-pump circuit. */

        port suction : RefrigerantPort;
        port discharge : RefrigerantPort;
        port electricalInput : ElectricalPort;
        port heatOutput : ThermalPort;

        attribute nominalCoolingCapacity : Power = 5200 [W];
        attribute nominalElectricalInput : Power = 1650 [W];
        attribute nominalSpeed : RotationalSpeed = 3600 [rpm];
        attribute designPressureRatio : Real = 3.2;
        attribute isentropicEfficiency : Efficiency = 0.72;
        attribute volumetricEfficiency : Efficiency = 0.88;
        attribute maximumDischargePressure : Pressure = 3200000 [Pa];
        attribute minimumSuctionPressure : Pressure = 220000 [Pa];
        attribute maximumWindingTemperature : Temperature = 423 [K];

        part hermeticShell : HermeticShell;
        part motorDrive : ElectricMotorDrive;
        part crankshaft : CrankshaftAssembly;
        part compressionSet : ScrollCompressionSet;
        part bearings : BearingSet;
        part oilManagement : OilManagementSystem;
        part suctionMuffler : SuctionMuffler;
        part dischargeValve : DischargeCheckValve;
        part protectionController : CompressorProtectionController;

        connect electricalInput to motorDrive.powerInput;
        connect motorDrive.shaftOutput to crankshaft.shaftInput;
        connect crankshaft.eccentricOutput to compressionSet.orbitInput;
        connect suction to suctionMuffler.inlet;
        connect suctionMuffler.outlet to compressionSet.suctionInlet;
        connect compressionSet.dischargeOutlet to dischargeValve.inlet;
        connect dischargeValve.outlet to discharge;
        connect oilManagement.oilFeed to bearings.lubricationInput;
        connect oilManagement.oilFeed to compressionSet.lubricationInput;
        connect hermeticShell.thermalOutlet to heatOutput;

        action compressRefrigerant {
            in item lowPressureVapor : Refrigerant;
            in item electricSupply : ElectricalPower;
            out item highPressureVapor : Refrigerant;

            first startMotor;
            then establishOrbitingMotion;
            then drawSuctionGas;
            then trapGasPockets;
            then reducePocketVolume;
            then dischargeCompressedGas;

            action startMotor {
                in item power : ElectricalPower = electricSupply;
                out item shaftPower : MechanicalPower;
            }

            action establishOrbitingMotion {
                in item shaftPower : MechanicalPower;
                out item orbitMotion : MechanicalPower;
            }

            action drawSuctionGas {
                in item vapor : Refrigerant = lowPressureVapor;
                out item suctionPocketCharge : Refrigerant;
            }

            action trapGasPockets {
                in item suctionPocketCharge : Refrigerant;
                out item sealedPocketCharge : Refrigerant;
            }

            action reducePocketVolume {
                in item sealedPocketCharge : Refrigerant;
                out item compressedPocketCharge : Refrigerant;
            }

            action dischargeCompressedGas {
                in item compressedPocketCharge : Refrigerant;
                out item vapor : Refrigerant = highPressureVapor;
            }
        }

        state def OperatingState {
            state Off;
            state Starting;
            state Running;
            state Unloading;
            state FaultLocked;
            state Shutdown;

            transition first Off;
            transition Off_to_Starting
                first Off
                then Starting
                accept StartCommand
                if protectionController.startPermitted;

            transition Starting_to_Running
                first Starting
                then Running
                if motorDrive.actualSpeed >= 0.95 * nominalSpeed;

            transition Running_to_Unloading
                first Running
                then Unloading
                accept CapacityReduceCommand;

            transition Unloading_to_Running
                first Unloading
                then Running
                accept CapacityRestoreCommand;

            transition Running_to_Shutdown
                first Running
                then Shutdown
                accept StopCommand;

            transition Shutdown_to_Off
                first Shutdown
                then Off
                if motorDrive.actualSpeed <= 50 [rpm];

            transition Any_to_FaultLocked
                first Off
                then FaultLocked
                accept FaultDetected;

            transition FaultLocked_to_Off
                first FaultLocked
                then Off
                accept ManualResetCommand
                if protectionController.faultCleared;
        }
    }

    part def HermeticShell {
        port suctionPassThrough : RefrigerantPort;
        port dischargePassThrough : RefrigerantPort;
        port thermalOutlet : ThermalPort;

        attribute internalVolume : Real = 0.0042;
        attribute designBurstPressure : Pressure = 12000000 [Pa];
        attribute steadyCasingTemperature : Temperature;
        attribute acousticAttenuation : Real = 18;

        part steelCan;
        part weldedCover;
        part electricalTerminalBlock;
        part mountingFeet;
    }

    part def ElectricMotorDrive {
        port powerInput : ElectricalPort;
        port shaftOutput : MechanicalPort;

        attribute ratedPower : Power = 2200 [W];
        attribute ratedVoltage : Real = 230;
        attribute phaseCount : Integer = 1;
        attribute actualSpeed : RotationalSpeed;
        attribute lockedRotorCurrent : Real = 42;
        attribute windingTemperature : Temperature;
        attribute motorEfficiency : Efficiency = 0.86;

        part stator;
        part rotor;
        part thermalProtector;
        part inverterInterface;

        action convertElectricalToMechanical {
            in item electricalEnergy : ElectricalPower;
            out item rotatingShaftPower : MechanicalPower;
        }
    }

    part def CrankshaftAssembly {
        port shaftInput : MechanicalPort;
        port eccentricOutput : MechanicalPort;

        attribute eccentricRadius : Real = 0.0038;
        attribute shaftDiameter : Real = 0.018;
        attribute nominalTorque : Torque = 4.4 [N*m];

        part mainShaft;
        part eccentricPin;
        part counterweight;

        action createOrbitalMotion {
            in item motorRotation : MechanicalPower;
            out item orbitingDrive : MechanicalPower;
        }
    }

    part def ScrollCompressionSet {
        port suctionInlet : RefrigerantPort;
        port dischargeOutlet : RefrigerantPort;
        port orbitInput : MechanicalPort;
        port lubricationInput : OilPort;

        attribute fixedScrollWrapHeight : Real = 0.026;
        attribute orbitingScrollWrapHeight : Real = 0.026;
        attribute builtInVolumeRatio : Real = 2.8;
        attribute displacementPerRevolution : Real = 0.000024;
        attribute radialComplianceForce : Real = 420;
        attribute axialSealingForce : Real = 760;

        part fixedScroll : FixedScroll;
        part orbitingScroll : OrbitingScroll;
        part oldhamCoupling : OldhamCoupling;
        part tipSeals : TipSealSet;
        part compressionPockets : CompressionPocket[3];

        connect orbitInput to orbitingScroll.drivePort;
        connect orbitingScroll.antiRotationPort to oldhamCoupling.orbitingSide;
        connect fixedScroll.referencePort to oldhamCoupling.fixedSide;

        action performScrollCompression {
            in item suctionVapor : Refrigerant;
            in item orbitalPower : MechanicalPower;
            out item dischargeVapor : Refrigerant;
        }
    }

    part def FixedScroll {
        port referencePort : MechanicalPort;
        attribute basePlateThickness : Real = 0.012;
        attribute wrapThickness : Real = 0.004;
        attribute dischargePortDiameter : Real = 0.006;
    }

    part def OrbitingScroll {
        port drivePort : MechanicalPort;
        port antiRotationPort : MechanicalPort;
        attribute orbitRadius : Real = 0.0038;
        attribute mass : Real = 0.92;
        attribute wrapThickness : Real = 0.004;
    }

    part def OldhamCoupling {
        port fixedSide : MechanicalPort;
        port orbitingSide : MechanicalPort;
        attribute slidingLossPower : Power;
        attribute allowableTangentialForce : Real = 1200;
    }

    part def TipSealSet {
        attribute leakageMassFlow : MassFlowRate;
        attribute sealMaterialLimitTemperature : Temperature = 448 [K];
    }

    part def CompressionPocket {
        attribute inletVolume : Real = 0.000012;
        attribute outletVolume : Real = 0.0000043;
        attribute pocketPressure : Pressure;
        attribute pocketTemperature : Temperature;
        attribute trappedMass : Real;
    }

    port def OilPort {
        inout item oil : LubricatingOil;
    }

    item def LubricatingOil {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute flowRate : VolumeFlowRate;
        attribute viscosity : Real;
    }

    part def BearingSet {
        port lubricationInput : OilPort;

        attribute radialLoadCapacity : Real = 1800;
        attribute thrustLoadCapacity : Real = 2600;
        attribute bearingLossPower : Power;

        part upperMainBearing;
        part lowerMainBearing;
        part thrustBearing;
    }

    part def OilManagementSystem {
        port oilFeed : OilPort;

        attribute sumpVolume : Real = 0.00065;
        attribute nominalOilFlow : VolumeFlowRate = 0.000003;
        attribute oilSumpTemperature : Temperature;
        attribute minimumOilLevel : Real = 0.00025;

        part oilSump;
        part centrifugalPump;
        part oilGallery;
        part oilSeparator;

        action circulateOil {
            out item pressurizedOil : LubricatingOil;
        }
    }

    part def SuctionMuffler {
        port inlet : RefrigerantPort;
        port outlet : RefrigerantPort;

        attribute pressureDrop : Pressure = 850 [Pa];
        attribute noiseReduction : Real = 9;
        attribute internalVolume : Real = 0.00048;
    }

    part def DischargeCheckValve {
        port inlet : RefrigerantPort;
        port outlet : RefrigerantPort;

        attribute crackingPressure : Pressure = 12000 [Pa];
        attribute reverseLeakage : MassFlowRate = 0.000001 [kg/s];

        state def ValveState {
            state Closed;
            state Opening;
            state Open;

            transition first Closed;
            transition Closed_to_Opening
                first Closed
                then Opening
                if inlet.fluid.pressure - outlet.fluid.pressure >= crackingPressure;

            transition Opening_to_Open
                first Opening
                then Open;

            transition Open_to_Closed
                first Open
                then Closed
                if inlet.fluid.pressure <= outlet.fluid.pressure;
        }
    }

    part def CompressorProtectionController {
        attribute startPermitted : Boolean;
        attribute faultCleared : Boolean;
        attribute measuredDischargePressure : Pressure;
        attribute measuredSuctionPressure : Pressure;
        attribute measuredWindingTemperature : Temperature;
        attribute measuredCurrent : Real;

        action evaluateProtection {
            in attribute dischargePressure : Pressure;
            in attribute suctionPressure : Pressure;
            in attribute windingTemperature : Temperature;
            in attribute motorCurrent : Real;
            out attribute permitRun : Boolean;
            out attribute tripFault : Boolean;
        }
    }

    requirement def CompressLowPressureVapor {
        subject compressor : ScrollCompressorSystem;
        doc /* The compressor shall raise refrigerant vapor pressure by trapping suction gas in scroll pockets and reducing the pocket volume through orbiting scroll motion. */
        require constraint {
            compressor.discharge.fluid.pressure >= compressor.designPressureRatio * compressor.suction.fluid.pressure
        }
    }

    requirement def ProvideHermeticContainment {
        subject compressor : ScrollCompressorSystem;
        doc /* The compressor shall contain refrigerant, oil, motor, and compression mechanism inside a welded hermetic shell. */
        require constraint {
            compressor.hermeticShell.designBurstPressure >= 3.0 * compressor.maximumDischargePressure
        }
    }

    requirement def LimitDischargePressure {
        subject compressor : ScrollCompressorSystem;
        doc /* The compressor shall not continue operation above the allowable discharge pressure. */
        require constraint {
            compressor.protectionController.measuredDischargePressure <= compressor.maximumDischargePressure
        }
    }

    requirement def ProtectMotorTemperature {
        subject compressor : ScrollCompressorSystem;
        doc /* The compressor shall remove electrical input or prevent start when winding temperature exceeds the safe limit. */
        require constraint {
            compressor.protectionController.measuredWindingTemperature <= compressor.maximumWindingTemperature
        }
    }

    requirement def MaintainLubrication {
        subject compressor : ScrollCompressorSystem;
        doc /* The oil management system shall supply lubricant to bearings and scroll contact surfaces during compressor operation. */
        require constraint {
            compressor.oilManagement.nominalOilFlow >= 0.000002 [m^3/s]
        }
    }

    requirement def PreventReverseFlow {
        subject compressor : ScrollCompressorSystem;
        doc /* The discharge check valve shall restrict reverse refrigerant flow from the high-pressure side to the compression chamber after shutdown. */
        require constraint {
            compressor.dischargeValve.reverseLeakage <= 0.000002 [kg/s]
        }
    }

    requirement def AchieveMinimumEfficiency {
        subject compressor : ScrollCompressorSystem;
        doc /* The compressor shall meet minimum thermodynamic and volumetric performance targets at nominal operating speed. */
        require constraint {
            compressor.isentropicEfficiency >= 0.68 and compressor.volumetricEfficiency >= 0.84
        }
    }

    satisfy CompressLowPressureVapor by ScrollCompressorSystem::compressionSet;
    satisfy ProvideHermeticContainment by ScrollCompressorSystem::hermeticShell;
    satisfy LimitDischargePressure by ScrollCompressorSystem::protectionController;
    satisfy ProtectMotorTemperature by ScrollCompressorSystem::motorDrive;
    satisfy MaintainLubrication by ScrollCompressorSystem::oilManagement;
    satisfy PreventReverseFlow by ScrollCompressorSystem::dischargeValve;
    satisfy AchieveMinimumEfficiency by ScrollCompressorSystem::compressionSet;
}