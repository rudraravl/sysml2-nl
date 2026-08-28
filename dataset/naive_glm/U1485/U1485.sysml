package RootsSuperchargerSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQBase::*;
    
    // ============================================================
    // Value Types with Units
    // ============================================================
    attribute def PressureValue :> Real {
        unit = "Pa";
        min = 0;
    }
    attribute def BoostPressureValue :> Real {
        unit = "Pa";
        min = 0;
    }
    attribute def TemperatureValue :> Real {
        unit = "K";
        min = 0;
    }
    attribute def MassFlowRateValue :> Real {
        unit = "kg/s";
        min = 0;
    }
    attribute def VolumeFlowRateValue :> Real {
        unit = "m3/s";
        min = 0;
    }
    attribute def AngularSpeedValue :> Real {
        unit = "rad/s";
        min = 0;
    }
    attribute def RotationalSpeedValue :> Real {
        unit = "1/min";
        min = 0;
    }
    attribute def TorqueValue :> Real {
        unit = "N.m";
        min = 0;
    }
    attribute def PowerValue :> Real {
        unit = "W";
        min = 0;
    }
    attribute def VolumeValue :> Real {
        unit = "m3";
        min = 0;
    }
    attribute def EfficiencyValue :> Real {
        unit = "1";
        min = 0;
        max = 1;
    }
    attribute def LengthValue :> Real {
        unit = "m";
        min = 0;
    }
    attribute def MassValue :> Real {
        unit = "kg";
        min = 0;
    }
    attribute def HeatRateValue :> Real {
        unit = "W";
        min = 0;
    }
    attribute def RatioValue :> Real {
        unit = "1";
        min = 0;
    }
    attribute def DensityValue :> Real {
        unit = "kg/m3";
        min = 0;
    }
    attribute def ViscosityValue :> Real {
        unit = "Pa.s";
        min = 0;
    }
    attribute def ForceValue :> Real {
        unit = "N";
        min = 0;
    }
    attribute def AreaValue :> Real {
        unit = "m2";
        min = 0;
    }
    attribute def AngleValue :> Real {
        unit = "deg";
    }
    
    // ============================================================
    // Item Types
    // ============================================================
    item def AmbientAir {
        attribute temperature : TemperatureValue = 298.15;
        attribute pressure : PressureValue = 101325;
        attribute humidity : RatioValue = 0.5;
        attribute density : DensityValue = 1.225;
    }
    item def AirCharge :> AmbientAir {
        attribute massFlowRate : MassFlowRateValue;
    }
    item def PressurizedAir :> AirCharge {
        attribute boostPressure : BoostPressureValue;
        attribute temperature : TemperatureValue;
        attribute density : DensityValue;
    }
    item def CooledAirCharge :> PressurizedAir {
        attribute temperature : TemperatureValue;
    }
    item def LubricatingOil {
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute massFlowRate : MassFlowRateValue;
        attribute viscosity : ViscosityValue;
        attribute grade : String = "ISO 75W90";
    }
    item def Coolant {
        attribute temperature : TemperatureValue;
        attribute massFlowRate : MassFlowRateValue;
        attribute specificHeat : Real { unit = "J/(kg.K)"; } = 4186;
    }
    item def ExhaustGas {
        attribute temperature : TemperatureValue;
        attribute massFlowRate : MassFlowRateValue;
        attribute pressure : PressureValue;
    }
    
    // ============================================================
    // Ports
    // ============================================================
    port def AirInPort {
        in air : AirCharge;
    }
    port def AirOutPort {
        out air : AirCharge;
    }
    port def PressurizedAirInPort {
        in air : PressurizedAir;
    }
    port def PressurizedAirOutPort {
        out air : PressurizedAir;
    }
    port def CooledAirInPort {
        in air : CooledAirCharge;
    }
    port def CooledAirOutPort {
        out air : CooledAirCharge;
    }
    port def OilInPort {
        in oil : LubricatingOil;
    }
    port def OilOutPort {
        out oil : LubricatingOil;
    }
    port def CoolantInPort {
        in coolant : Coolant;
    }
    port def CoolantOutPort {
        out coolant : Coolant;
    }
    port def MechDrivePort {
        in torque : TorqueValue;
        in speed : AngularSpeedValue;
        attribute transmittedPower : PowerValue;
    }
    port def MechOutputPort {
        out torque : TorqueValue;
        out speed : AngularSpeedValue;
        attribute transmittedPower : PowerValue;
    }
    
    // ============================================================
    // Connection Definitions
    // ============================================================
    connection def AirConduit {
        end source : AirOutPort;
        end target : AirInPort;
    }
    connection def PressurizedAirConduit {
        end source : PressurizedAirOutPort;
        end target : PressurizedAirInPort;
    }
    connection def CooledAirConduit {
        end source : CooledAirOutPort;
        end target : CooledAirInPort;
    }
    connection def OilLine {
        end source : OilOutPort;
        end target : OilInPort;
    }
    connection def CoolantLine {
        end source : CoolantOutPort;
        end target : CoolantInPort;
    }
    connection def BeltLink {
        end source : MechOutputPort;
        end target : MechDrivePort;
    }
    
    // ============================================================
    // Action Definitions
    // ============================================================
    action def IntakeAmbientAir {
        in ambientAir : AmbientAir;
        out trappedAir : AirCharge;
        doc "Trap ambient air in rotor pockets at the intake port.";
    }
    action def TransportAirPocket {
        in trappedAir : AirCharge;
        out transportedAir : AirCharge;
        doc "Move trapped air pocket from intake to discharge along rotor cavity without internal compression.";
    }
    action def DischargeAirPocket {
        in transportedAir : AirCharge;
        out highPressureAir : PressurizedAir;
        doc "Discharge air pocket into higher-pressure intake manifold; compression occurs here.";
    }
    action def CompressionCycle {
        in ambientAir : AmbientAir;
        out highPressureAir : PressurizedAir;
        
        action intake : IntakeAmbientAir;
        action transport : TransportAirPocket;
        action discharge : DischargeAirPocket;
        
        flow from ambientAir to intake.ambientAir;
        flow from intake.trappedAir to transport.trappedAir;
        flow from transport.transportedAir to discharge.transportedAir;
        flow from discharge.highPressureAir to highPressureAir;
    }
    action def IntercoolerHeatExchange {
        in hotAir : PressurizedAir;
        in coolant : Coolant;
        out cooledAir : CooledAirCharge;
        out heatedCoolant : Coolant;
        doc "Cool pressurized air by transferring heat to coolant.";
    }
    action def DistributeAirToCylinders {
        in incomingAir : CooledAirCharge;
        out distributedAir : CooledAirCharge;
        doc "Distribute cooled, dense air evenly to each engine cylinder runner.";
    }
    action def PumpOil {
        in suctionOil : LubricatingOil;
        out pressurizedOil : LubricatingOil;
        doc "Draw oil from reservoir and discharge to pressurized lubrication circuit.";
    }
    action def CoolOil {
        in hotOil : LubricatingOil;
        in coolant : Coolant;
        out cooledOil : LubricatingOil;
        out heatedCoolant : Coolant;
        doc "Reject oil heat to coolant in oil cooler heat exchanger.";
    }
    action def PumpCoolant {
        in suctionCoolant : Coolant;
        out pressurizedCoolant : Coolant;
        doc "Circulate coolant through closed cooling circuit.";
    }
    action def RejectCoolantHeat {
        in hotCoolant : Coolant;
        out cooledCoolant : Coolant;
        doc "Reject coolant heat to ambient at radiator.";
    }
    action def CombustionStroke {
        in intakeAir : CooledAirCharge;
        in fuelMass : MassValue;
        out exhaust : ExhaustGas;
        out mechWork : PowerValue;
        doc "Burn air-fuel mixture in cylinder to produce mechanical work and exhaust gas.";
    }
    
    // ============================================================
    // State Machine Definitions
    // ============================================================
    state def SuperchargerOperationalStates {
        state Off;
        state Starting;
        state Running;
        state OvertempShutdown;
        state Fault;
        
        attribute ignitionOn : Boolean;
        attribute rotorSpeed : RotationalSpeedValue;
        attribute dischargeTemp : TemperatureValue;
        attribute resetRequested : Boolean;
        attribute overspeedDetected : Boolean;
        
        transition from Off to Starting when ignitionOn == true;
        transition from Starting to Running when rotorSpeed > 1000;
        transition from Starting to Off when ignitionOn == false;
        transition from Running to OvertempShutdown when dischargeTemp > 453.15;
        transition from Running to Off when ignitionOn == false;
        transition from Running to Fault when overspeedDetected == true;
        transition from OvertempShutdown to Off when resetRequested == true;
        transition from Fault to Off when resetRequested == true;
    }
    state def LubricationStates {
        state Idle;
        state Pressurized;
        state LowOilWarning;
        state LossOfPressure;
        
        attribute pumpActive : Boolean;
        attribute oilPressure : PressureValue;
        attribute operatorReset : Boolean;
        
        transition from Idle to Pressurized when pumpActive == true;
        transition from Pressurized to Idle when pumpActive == false;
        transition from Pressurized to LowOilWarning when oilPressure < 100000;
        transition from LowOilWarning to Pressurized when oilPressure > 150000;
        transition from LowOilWarning to LossOfPressure when oilPressure < 50000;
        transition from LossOfPressure to Idle when operatorReset == true;
    }
    state def EngineOperationalStates {
        state Cranking;
        state Idling;
        state UnderLoad;
        state Stalled;
        
        attribute ignitionOn : Boolean;
        attribute loadDemand : PowerValue;
        attribute rotorSpeed : RotationalSpeedValue;
        
        transition from Cranking to Idling when rotorSpeed > 800;
        transition from Idling to UnderLoad when loadDemand > 1000;
        transition from UnderLoad to Idling when loadDemand <= 1000;
        transition from Idling to Cranking when ignitionOn == false;
    }
    
    // ============================================================
    // Rotor and Bearing Parts
    // ============================================================
    part def Rotor {
        abstract;
        attribute lobeCount : Integer = 3;
        attribute helixAngle : AngleValue;
        attribute length : LengthValue;
        attribute diameter : LengthValue;
        attribute mass : MassValue;
        attribute isBalanced : Boolean = true;
        attribute balanceGrade : Real;
        attribute rotationDirection : String;
        attribute surfaceFinish : Real { unit = "um"; } = 0.8;
    }
    part def MaleRotor :> Rotor {
        attribute lobeCount = 3;
        attribute helixAngle = 30.0;
        attribute length = 0.20;
        attribute diameter = 0.10;
        attribute mass = 2.5;
        attribute rotationDirection = "clockwise";
        attribute balanceGrade = 2.5;
    }
    part def FemaleRotor :> Rotor {
        attribute lobeCount = 3;
        attribute helixAngle = -30.0;
        attribute length = 0.20;
        attribute diameter = 0.10;
        attribute mass = 2.5;
        attribute rotationDirection = "counter-clockwise";
        attribute balanceGrade = 2.5;
    }
    
    part def RollerBearing {
        attribute loadRating : ForceValue;
        attribute maxSpeed : RotationalSpeedValue = 18000;
        attribute lubricantType : String = "Synthetic";
        attribute boreDiameter : LengthValue;
        attribute outerDiameter : LengthValue;
        attribute heatGenerated : HeatRateValue;
        port lubricantIn : OilInPort;
        port lubricantOut : OilOutPort;
        connect lubricantIn to lubricantOut;
    }
    part def FrontRollerBearing :> RollerBearing {
        attribute loadRating = 25000;
        attribute boreDiameter = 0.025;
        attribute outerDiameter = 0.052;
    }
    part def RearRollerBearing :> RollerBearing {
        attribute loadRating = 25000;
        attribute boreDiameter = 0.025;
        attribute outerDiameter = 0.052;
    }
    
    part def SealElement {
        attribute material : String;
        attribute diameter : LengthValue;
        attribute maxTemp : TemperatureValue = 473.15;
    }
    part def LipSeal :> SealElement {
        attribute material = "PTFE";
    }
    part def ShaftSeal :> SealElement {
        attribute material = "FKM";
    }
    
    part def SealingSystem {
        doc "Prevents air leakage from rotor cavity and oil ingress into air stream.";
        attribute sealMaterial : String = "PTFE";
        attribute maxLeakage : MassFlowRateValue = 0.001;
        part frontLipSeal : LipSeal {
            attribute diameter = 0.030;
        }
        part rearLipSeal : LipSeal {
            attribute diameter = 0.030;
        }
        part frontShaftSeal : ShaftSeal {
            attribute diameter = 0.025;
        }
        part rearShaftSeal : ShaftSeal {
            attribute diameter = 0.025;
        }
        port oilIn : OilInPort;
        port oilOut : OilOutPort;
        connect oilIn to oilOut;
    }
    
    part def RotorAssembly {
        doc "Houses male and female rotors with roller bearings and sealing system.";
        part maleRotor : MaleRotor;
        part femaleRotor : FemaleRotor;
        part frontBearingMale : FrontRollerBearing;
        part rearBearingMale : RearRollerBearing;
        part frontBearingFemale : FrontRollerBearing;
        part rearBearingFemale : RearRollerBearing;
        part seals : SealingSystem;
        attribute rotorClearance : LengthValue = 0.0001;
        attribute maxSpeed : RotationalSpeedValue = 15000;
        attribute backlash : LengthValue = 0.00005;
        port oilIn : OilInPort;
        port oilOut : OilOutPort;
        
        connect oilIn to seals.oilIn;
        connect seals.oilOut to frontBearingMale.lubricantIn;
        connect frontBearingMale.lubricantOut to rearBearingMale.lubricantIn;
        connect rearBearingMale.lubricantOut to frontBearingFemale.lubricantIn;
        connect frontBearingFemale.lubricantOut to rearBearingFemale.lubricantIn;
        connect rearBearingFemale.lubricantOut to oilOut;
    }
    
    // ============================================================
    // Roots Supercharger
    // ============================================================
    part def RootsSupercharger {
        doc "Positive-displacement Roots-type supercharger with two three-lobe helical rotors.";
        attribute housingMaterial : String = "Aluminum 6061-T6";
        attribute displacementPerRev : VolumeValue = 1.5e-3;
        attribute maxBoostPressure : BoostPressureValue = 150000;
        attribute adiabaticEfficiency : EfficiencyValue = 0.60;
        attribute operatingSpeed : RotationalSpeedValue;
        attribute thermalLimit : TemperatureValue = 453.15;
        attribute volumetricEfficiency : EfficiencyValue = 0.92;
        attribute nominalDriveRatio : RatioValue = 2.5;
        
        port airIntake : AirInPort;
        port airDischarge : PressurizedAirOutPort;
        port mechInput : MechDrivePort;
        port oilIn : OilInPort;
        port oilOut : OilOutPort;
        
        part rotorAssembly : RotorAssembly;
        
        state opStates : SuperchargerOperationalStates;
        action compress : CompressionCycle;
        
        connect airIntake to compress.ambientAir;
        connect compress.highPressureAir to airDischarge;
        connect oilIn to rotorAssembly.oilIn;
        connect rotorAssembly.oilOut to oilOut;
    }
    
    // ============================================================
    // Belt Drive
    // ============================================================
    part def Pulley {
        attribute diameter : LengthValue;
        attribute mass : MassValue;
        attribute material : String = "Aluminum";
        attribute toothCount : Integer;
        port mechIn : MechDrivePort;
        port mechOut : MechOutputPort;
        attribute ratio : RatioValue;
        connect mechIn to mechOut;
    }
    part def Belt {
        attribute length : LengthValue;
        attribute type : String = "Multi-rib";
        attribute material : String = "EPDM";
        attribute efficiency : EfficiencyValue = 0.97;
        attribute width : LengthValue = 0.024;
    }
    part def BeltDrive {
        doc "Mechanical drive from engine crankshaft to supercharger via belt and pulleys.";
        attribute driveRatio : RatioValue = 2.5;
        attribute beltEfficiency : EfficiencyValue = 0.97;
        attribute totalLength : LengthValue;
        port driveIn : MechOutputPort;
        port driveOut : MechOutputPort;
        
        part drivePulley : Pulley {
            attribute diameter = 0.150;
            attribute mass = 1.2;
            attribute ratio = 1.0;
        }
        part drivenPulley : Pulley {
            attribute diameter = 0.060;
            attribute mass = 0.5;
            attribute ratio = 2.5;
        }
        part belt : Belt {
            attribute length = 0.850;
        }
        part idlerPulley : Pulley {
            attribute diameter = 0.070;
            attribute mass = 0.4;
            attribute ratio = 1.0;
        }
        part tensioner {
            attribute targetTension : ForceValue = 350;
        }
        
        connect driveIn to drivePulley.mechIn;
        connect drivePulley.mechOut to belt;
        connect belt to drivenPulley.mechIn;
        connect drivenPulley.mechOut to driveOut;
    }
    
    // ============================================================
    // Engine
    // ============================================================
    part def Crankshaft {
        attribute maxRPM : RotationalSpeedValue = 7000;
        attribute currentTorque : TorqueValue;
        attribute currentSpeed : AngularSpeedValue;
        attribute stroke : LengthValue = 0.086;
        attribute journalDiameter : LengthValue = 0.060;
        port mechOutput : MechOutputPort;
    }
    part def Cylinder {
        attribute displacement : VolumeValue = 0.5e-3;
        attribute compressionRatio : RatioValue = 10.5;
        attribute bore : LengthValue = 0.090;
        attribute stroke : LengthValue = 0.086;
        port airIn : CooledAirInPort;
        port exhaustOut : out exhaust : ExhaustGas;
        action combustion : CombustionStroke;
        connect airIn to combustion.intakeAir;
        connect combustion.exhaust to exhaustOut;
    }
    part def Engine {
        doc "Internal combustion engine producing power via forced induction air charge.";
        attribute cylinderCount : Integer = 8;
        attribute totalDisplacement : VolumeValue = 4.0e-3;
        attribute maxPower : PowerValue = 450000;
        attribute maxTorque : TorqueValue = 600;
        attribute compressionRatio : RatioValue = 10.5;
        attribute configuration : String = "V8";
        
        part crankshaft : Crankshaft;
        part cylinders[cylinderCount] : Cylinder;
        
        port mechOutput : MechOutputPort;
        port intakeAir : CooledAirInPort;
        port exhaustOut : out exhaust : ExhaustGas;
        
        state engineStates : EngineOperationalStates;
        
        connect crankshaft.mechOutput to mechOutput;
        connect intakeAir to cylinders.airIn;
        connect cylinders.exhaustOut to exhaustOut;
    }
    
    // ============================================================
    // Intercooler
    // ============================================================
    part def Intercooler {
        doc "Air-to-liquid heat exchanger that cools hot, pressurized discharge air.";
        attribute heatTransferArea : AreaValue = 0.50;
        attribute effectiveness : EfficiencyValue = 0.70;
        attribute pressureDrop : PressureValue = 5000;
        attribute coolantType : String = "EthyleneGlycol50";
        attribute coreVolume : VolumeValue = 2.5e-3;
        
        port hotAirIn : PressurizedAirInPort;
        port cooledAirOut : CooledAirOutPort;
        port coolantIn : CoolantInPort;
        port coolantOut : CoolantOutPort;
        
        action exchange : IntercoolerHeatExchange;
        
        connect hotAirIn to exchange.hotAir;
        connect exchange.cooledAir to cooledAirOut;
        connect coolantIn to exchange.coolant;
        connect exchange.heatedCoolant to coolantOut;
    }
    
    // ============================================================
    // Intake Manifold
    // ============================================================
    part def IntakeManifold {
        doc "Plenum and runners that distribute cooled, dense air evenly to engine cylinders.";
        attribute plenumVolume : VolumeValue = 2.0e-3;
        attribute runnerCount : Integer = 8;
        attribute runnerLength : LengthValue = 0.150;
        attribute runnerDiameter : LengthValue = 0.050;
        attribute distributionUniformity : RatioValue = 0.95;
        attribute material : String = "Aluminum";
        
        port airIn : CooledAirInPort;
        port cylinderAirOut : CooledAirOutPort;
        
        action distribute : DistributeAirToCylinders;
        
        connect airIn to distribute.incomingAir;
        connect distribute.distributedAir to cylinderAirOut;
    }
    
    // ============================================================
    // Lubrication System
    // ============================================================
    part def OilPump {
        doc "Gerotor pump that pressurizes oil for supercharger bearing lubrication.";
        attribute flowRate : VolumeFlowRateValue = 0.5e-3;
        attribute targetPressure : PressureValue = 300000;
        attribute maxPressure : PressureValue = 500000;
        port suction : OilInPort;
        port discharge : OilOutPort;
        port mechIn : MechDrivePort;
        action pump : PumpOil;
        connect suction to pump.suctionOil;
        connect pump.pressurizedOil to discharge;
    }
    part def OilReservoir {
        doc "Oil sump providing steady suction supply to oil pump.";
        attribute capacity : VolumeValue = 2.0e-3;
        attribute fillLevel : RatioValue = 1.0;
        attribute oilType : String = "ISO 75W90";
        port oilOut : OilOutPort;
    }
    part def OilCooler {
        doc "Liquid-to-liquid cooler that rejects oil heat to coolant.";
        attribute heatDuty : HeatRateValue = 500;
        attribute heatTransferArea : AreaValue = 0.10;
        port oilIn : OilInPort;
        port oilOut : OilOutPort;
        port coolantIn : CoolantInPort;
        port coolantOut : CoolantOutPort;
        action cool : CoolOil;
        connect oilIn to cool.hotOil;
        connect cool.cooledOil to oilOut;
        connect coolantIn to cool.coolant;
        connect cool.heatedCoolant to coolantOut;
    }
    part def LubricationSystem {
        doc "Dedicated supercharger lubrication circuit with pump, reservoir, and cooler.";
        part oilPump : OilPump;
        part reservoir : OilReservoir;
        part cooler : OilCooler;
        
        port oilSupply : OilOutPort;
        port oilReturn : OilInPort;
        port mechDrive : MechDrivePort;
        port coolantIn : CoolantInPort;
        port coolantOut : CoolantOutPort;
        
        state lubeStates : LubricationStates;
        
        connect reservoir.oilOut to oilPump.suction;
        connect oilPump.discharge to cooler.oilIn;
        connect cooler.oilOut to oilSupply;
        connect oilReturn to reservoir;
        connect mechDrive to oilPump.mechIn;
        connect coolantIn to cooler.coolantIn;
        connect cooler.coolantOut to coolantOut;
    }
    
    // ============================================================
    // Coolant Circuit
    // ============================================================
    part def CoolantPump {
        doc "Electric or mechanical pump circulating coolant through cooling loop.";
        attribute flowRate : VolumeFlowRateValue = 1.0e-3;
        attribute targetPressure : PressureValue = 150000;
        port suction : CoolantInPort;
        port discharge : CoolantOutPort;
        port mechIn : MechDrivePort;
        action pump : PumpCoolant;
        connect suction to pump.suctionCoolant;
        connect pump.pressurizedCoolant to discharge;
    }
    part def Radiator {
        doc "Heat exchanger rejecting coolant heat to ambient environment.";
        attribute heatTransferArea : AreaValue = 0.80;
        attribute thermalRating : HeatRateValue = 1500;
        attribute ambientAirInlet : TemperatureValue = 298.15;
        port coolantIn : CoolantInPort;
        port coolantOut : CoolantOutPort;
        action reject : RejectCoolantHeat;
        connect coolantIn to reject.hotCoolant;
        connect reject.cooledCoolant to coolantOut;
    }
    part def CoolantReservoir {
        attribute capacity : VolumeValue = 1.5e-3;
        attribute fillLevel : RatioValue = 1.0;
        attribute coolantMixture : String = "EthyleneGlycol50";
        port coolantOut : CoolantOutPort;
    }
    part def CoolantCircuit {
        doc "Closed-loop coolant circuit serving intercooler and oil cooler.";
        part pump : CoolantPump;
        part radiator : Radiator;
        part reservoir : CoolantReservoir;
        
        port coolantSupply : CoolantOutPort;
        port coolantReturn : CoolantInPort;
        port mechDrive : MechDrivePort;
        
        connect reservoir.coolantOut to pump.suction;
        connect pump.discharge to coolantSupply;
        connect coolantReturn to radiator.coolantIn;
        connect radiator.coolantOut to reservoir;
        connect mechDrive to pump.mechIn;
    }
    
    // ============================================================
    // Top-Level Supercharger System
    // ============================================================
    part def RootsSuperchargerSystem {
        doc "High-performance Roots-type supercharger system for an internal combustion engine, providing forced induction to boost power and torque.";
        
        part engine : Engine;
        part supercharger : RootsSupercharger;
        part beltDrive : BeltDrive;
        part intercooler : Intercooler;
        part intakeManifold : IntakeManifold;
        part lubricationSystem : LubricationSystem;
        part coolantCircuit : CoolantCircuit;
        
        // Engine mechanical drive to supercharger via belt
        connect engine.mechOutput to beltDrive.driveIn;
        connect beltDrive.driveOut to supercharger.mechInput;
        
        // Air path: supercharger -> intercooler -> manifold -> engine
        connect supercharger.airDischarge to intercooler.hotAirIn;
        connect intercooler.cooledAirOut to intakeManifold.airIn;
        connect intakeManifold.cylinderAirOut to engine.intakeAir;
        
        // Lubrication circuit
        connect supercharger.oilOut to lubricationSystem.oilReturn;
        connect lubricationSystem.oilSupply to supercharger.oilIn;
        
        // Lubrication pump drive from engine
        connect engine.mechOutput to lubricationSystem.mechDrive;
        
        // Coolant circuit serving intercooler and oil cooler
        connect coolantCircuit.coolantSupply to intercooler.coolantIn;
        connect intercooler.coolantOut to lubricationSystem.coolantIn;
        connect lubricationSystem.coolantOut to coolantCircuit.coolantReturn;
        connect engine.mechOutput to coolantCircuit.mechDrive;
        
        // Satisfactions
        satisfy ForcedInductionReq by supercharger;
        satisfy BoostPressureReq by supercharger;
        satisfy RotorBalanceReq by supercharger.rotorAssembly.maleRotor;
        satisfy RotorBalanceReq by supercharger.rotorAssembly.femaleRotor;
        satisfy SealingIntegrityReq by supercharger.rotorAssembly.seals;
        satisfy LubricationReq by lubricationSystem;
        satisfy IntercoolerCoolingReq by intercooler;
        satisfy CoolantCircuitReq by coolantCircuit;
        satisfy DrivePowerReq by beltDrive;
        satisfy AirDistributionReq by intakeManifold;
    }
    
    // ============================================================
    // Requirements
    // ============================================================
    requirement def ForcedInductionReq {
        doc "The supercharger shall force more air into engine cylinders than naturally aspirated, increasing power and torque.";
        subject s : RootsSupercharger;
        attribute minBoostPressure : BoostPressureValue = 50000;
        attribute requiredAirFlow : MassFlowRateValue = 0.6;
        requirement pressureRequirement {
            s.maxBoostPressure >= minBoostPressure;
        }
        requirement flowRequirement {
            doc "Sufficient mass flow to support engine volumetric demand at full load.";
        }
    }
    requirement def BoostPressureReq {
        doc "The supercharger shall deliver at least 50 kPa boost pressure at rated speed.";
        subject s : RootsSupercharger;
        attribute targetBoost : BoostPressureValue = 150000;
        requirement boostAchieved {
            s.maxBoostPressure >= 100000;
        }
    }
    requirement def RotorBalanceReq {
        doc "Each rotor shall be precision-balanced to limit vibration at high rotational speeds.";
        subject r : Rotor;
        attribute maxBalanceGrade : Real = 2.5;
        requirement balanceConstraint {
            r.balanceGrade <= maxBalanceGrade;
            r.isBalanced == true;
        }
    }
    requirement def SealingIntegrityReq {
        doc "The sealing system shall prevent air leakage from the rotor cavity and oil ingress into the air stream.";
        subject seal : SealingSystem;
        attribute maxAllowableLeakage : MassFlowRateValue = 0.001;
        attribute sealMaterialRequired : String = "PTFE";
        requirement leakConstraint {
            seal.maxLeakage <= maxAllowableLeakage;
        }
        requirement materialConstraint {
            seal.sealMaterial == sealMaterialRequired;
        }
    }
    requirement def LubricationReq {
        doc "The lubrication system shall provide a continuous flow of cooled oil to supercharger bearings.";
        subject l : LubricationSystem;
        attribute minOilPressure : PressureValue = 150000;
        attribute maxOilTemp : TemperatureValue = 393.15;
        attribute minFlowRate : MassFlowRateValue = 0.05;
        requirement pressureMaintenance {
            doc "Oil pressure must remain above minimum threshold during operation.";
        }
        requirement temperatureLimit {
            doc "Oil temperature must remain below degradation limit.";
        }
    }
    requirement def IntercoolerCoolingReq {
        doc "The intercooler shall reduce discharge air temperature to increase density and oxygen content for combustion.";
        subject c : Intercooler;
        attribute targetDischargeTemp : TemperatureValue = 323.15;
        attribute minEffectiveness : EfficiencyValue = 0.60;
        attribute maxPressureDrop : PressureValue = 10000;
        requirement coolDown {
            c.effectiveness >= minEffectiveness;
        }
        requirement flowLoss {
            c.pressureDrop <= maxPressureDrop;
        }
    }
    requirement def CoolantCircuitReq {
        doc "The coolant circuit shall continuously supply coolant to intercooler and oil cooler at sufficient flow rate.";
        subject c : CoolantCircuit;
        attribute requiredFlow : VolumeFlowRateValue = 0.8e-3;
        attribute pumpTargetPressure : PressureValue = 150000;
        requirement flowContinuity {
            doc "Coolant flow must be maintained under all operating conditions.";
        }
    }
    requirement def DrivePowerReq {
        doc "The belt drive shall transmit engine power to the supercharger at the required drive ratio.";
        subject b : BeltDrive;
        attribute requiredDriveRatio : RatioValue = 2.5;
        attribute minEfficiency : EfficiencyValue = 0.95;
        requirement ratioSpec {
            b.driveRatio == requiredDriveRatio;
        }
        requirement efficiencySpec {
            b.beltEfficiency >= minEfficiency;
        }
    }
    requirement def AirDistributionReq {
        doc "The intake manifold shall distribute the cooled, dense air evenly to each engine cylinder.";
        subject m : IntakeManifold;
        attribute minUniformity : RatioValue = 0.90;
        attribute runnerCountRequired : Integer = 8;
        requirement uniformitySpec {
            m.distributionUniformity >= minUniformity;
        }
        requirement runnerCountSpec {
            m.runnerCount == runnerCountRequired;
        }
    }
    requirement def SystemPerformanceReq {
        doc "The complete supercharger system shall increase engine power output by at least 30 percent over naturally aspirated baseline.";
        subject sys : RootsSuperchargerSystem;
        attribute minPowerIncrease : RatioValue = 0.3;
        attribute baselinePower : PowerValue = 320000;
        requirement powerGain {
            doc "Engine output with supercharger engaged shall exceed baseline plus minimum gain.";
        }
    }
    
    part RootsSuperchargerSystemInstance : RootsSuperchargerSystem {
        doc "Operational instance of the Roots supercharger system for a high-performance V8 engine.";
        satisfy SystemPerformanceReq by this;
    }
}
