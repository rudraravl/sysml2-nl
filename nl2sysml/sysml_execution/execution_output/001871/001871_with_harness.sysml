package SteamPumpSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SteamQuality :> Real;
    attribute def EfficiencyFactor :> Real;
    
    item def SteamFlow {
        attribute pressure :> ISQ::pressure;
        attribute temperature :> ISQ::temperature;
        attribute massFlowRate :> ISQ::massFlowRate;
        attribute quality : SteamQuality;
    }
    
    item def WaterFlow {
        attribute pressure :> ISQ::pressure;
        attribute temperature :> ISQ::temperature;
        attribute volumeFlowRate :> ISQ::volumeFlowRate;
    }
    
    item def MechanicalWork {
        attribute power :> ISQ::power;
        attribute torque :> ISQ::torque;
        attribute rotationalSpeed :> ISQ::angularVelocity;
    }
    
    item def StartCommand;
    item def StopCommand;
    
    port def SteamInletPort {
        in item steamSupply : SteamFlow;
    }
    
    port def SteamExhaustPort {
        out item steamExhaust : SteamFlow;
    }
    
    port def WaterInletPort {
        in item waterSupply : WaterFlow;
    }
    
    port def WaterDischargePort {
        out item waterDischarge : WaterFlow;
    }
    
    port def MechanicalPowerPort {
        out item mechanicalPower : MechanicalWork;
    }
    
    part def SteamCylinder {
        port steamIn : SteamInletPort;
        port steamOut : SteamExhaustPort;
        port powerOut : MechanicalPowerPort;
        
        attribute cylinderVolume :> ISQ::volume;
        attribute strokeLength :> ISQ::length;
        attribute pistonDiameter :> ISQ::length;
        attribute cycleFrequency :> ISQ::frequency;
        
        perform action convertSteamToPower {
            in highPressureSteam : SteamFlow;
            out mechanicalOutput : MechanicalWork;
            out exhaustedSteam : SteamFlow;
        }
    }
    
    part def ReciprocatingPump {
        port powerIn : MechanicalPowerPort;
        port waterIn : WaterInletPort;
        port waterOut : WaterDischargePort;
        
        attribute pumpDisplacement :> ISQ::volume;
        attribute dischargePressure :> ISQ::pressure;
        attribute pumpEfficiency : EfficiencyFactor;
        
        perform action pumpWater {
            in drivePower : MechanicalWork;
            in inletWater : WaterFlow;
            out dischargedWater : WaterFlow;
        }
    }
    
    part def SteamBoiler {
        port steamOutput : SteamExhaustPort;
        
        attribute operatingPressure :> ISQ::pressure;
        attribute operatingTemperature :> ISQ::temperature;
        attribute steamProductionRate :> ISQ::massFlowRate;
        
        perform action produceSteam {
            out generatedSteam : SteamFlow;
        }
    }
    
    part def CheckValve {
        port inlet : WaterInletPort;
        port outlet : WaterDischargePort;
        
        attribute crackingPressure :> ISQ::pressure;
        
        perform action preventBackflow {
            in flowDirection :> ISQ::pressure;
            out allowFlow : Boolean;
        }
    }
    
    part def Condenser {
        port steamIn : SteamInletPort;
        port condensateOut : WaterDischargePort;
        
        attribute coolingWaterFlow :> ISQ::volumeFlowRate;
        attribute condensationRate :> ISQ::massFlowRate;
        
        perform action condenseSteam {
            in exhaustSteam : SteamFlow;
            out condensedWater : WaterFlow;
        }
    }
    
    part def PressureGauge {
        attribute measuredPressure :> ISQ::pressure;
        
        perform action measurePressure {
            out pressureReading :> ISQ::pressure;
        }
    }
    
    part def FlowMeter {
        attribute measuredFlow :> ISQ::volumeFlowRate;
        
        perform action measureFlow {
            out flowReading :> ISQ::volumeFlowRate;
        }
    }
    
    part def SafetyValve {
        attribute reliefPressure :> ISQ::pressure;
        
        perform action relievePressure {
            in systemPressure :> ISQ::pressure;
            out vented : Boolean;
        }
    }
    
    state def SteamPumpOperatingStates {
        entry; then stopped;
        
        state stopped {
            entry assign steamValveClosed := true;
            entry assign pumpSpeed := 0.0;
        }
        
        transition stopped_to_starting
            first stopped
            accept at startEvent : StartCommand
            then starting;
        
        state starting {
            entry assign steamValveClosed := false;
            do action warmupCylinder;
            do action primeWaterChamber;
        }
        
        transition starting_to_operating
            first starting
            if systemReady
            then operating;
        
        state operating {
            do action maintainSteamFlow;
            do action regulateWaterPressure;
            
            state normalOperation {
                do action cyclePiston;
            }
            
            state highDemand {
                entry assign steamFlowRate := maxSteamFlow;
            }
            
            state lowDemand {
                entry assign steamFlowRate := minSteamFlow;
            }
            
            transition normal_to_high
                first normalOperation
                if demandIncreased
                then highDemand;
            
            transition high_to_normal
                first highDemand
                if demandNormalized
                then normalOperation;
            
            transition normal_to_low
                first normalOperation
                if demandDecreased
                then lowDemand;
            
            transition low_to_normal
                first lowDemand
                if demandNormalized
                then normalOperation;
        }
        
        transition operating_to_stopping
            first operating
            accept at stopEvent : StopCommand
            then stopping;
        
        state stopping {
            entry assign steamValveClosed := true;
            do action coastDown;
        }
        
        transition stopping_to_stopped
            first stopping
            if pumpSpeed == 0.0
            then stopped;
        
        state emergency {
            entry assign steamValveClosed := true;
            entry assign emergencyVentOpen := true;
        }
        
        transition any_to_emergency
            first operating
            if overpressureDetected or mechanicalFailure
            then emergency;
        
        transition emergency_to_stopped
            first emergency
            if systemSafe
            then stopped;
        
        attribute steamValveClosed : Boolean;
        attribute pumpSpeed : ScalarValues::Real;
        attribute systemReady : Boolean;
        attribute demandIncreased : Boolean;
        attribute demandDecreased : Boolean;
        attribute demandNormalized : Boolean;
        attribute overpressureDetected : Boolean;
        attribute mechanicalFailure : Boolean;
        attribute systemSafe : Boolean;
        attribute emergencyVentOpen : Boolean;
        attribute steamFlowRate :> ISQ::massFlowRate;
        attribute maxSteamFlow :> ISQ::massFlowRate;
        attribute minSteamFlow :> ISQ::massFlowRate;
    }
    
    part def SteamPump {
        attribute designPressure :> ISQ::pressure;
        attribute designFlowRate :> ISQ::volumeFlowRate;
        attribute overallEfficiency : EfficiencyFactor;
        
        part boiler : SteamBoiler {
            attribute :>> operatingPressure = 1000.0 [SI::kPa];
            attribute :>> operatingTemperature = 453.15 [SI::K];
            attribute :>> steamProductionRate = 2.5 [SI::kg/SI::s];
        }
        
        part steamCylinder : SteamCylinder {
            attribute :>> cylinderVolume = 0.05 [SI::m^3];
            attribute :>> strokeLength = 0.3 [SI::m];
            attribute :>> pistonDiameter = 0.25 [SI::m];
            attribute :>> cycleFrequency = 1.5 [SI::Hz];
        }
        
        part reciprocatingPump : ReciprocatingPump {
            attribute :>> pumpDisplacement = 0.04 [SI::m^3];
            attribute :>> dischargePressure = 800.0 [SI::kPa];
            attribute :>> pumpEfficiency = 0.75;
        }
        
        part suctionValve : CheckValve {
            attribute :>> crackingPressure = 5.0 [SI::kPa];
        }
        
        part dischargeValve : CheckValve {
            attribute :>> crackingPressure = 10.0 [SI::kPa];
        }
        
        part condenser : Condenser {
            attribute :>> coolingWaterFlow = 0.1 [SI::m^3/SI::s];
            attribute :>> condensationRate = 2.5 [SI::kg/SI::s];
        }
        
        part steamPressureGauge : PressureGauge;
        part dischargePressureGauge : PressureGauge;
        part flowMeter : FlowMeter;
        part safetyValve : SafetyValve {
            attribute :>> reliefPressure = 1200.0 [SI::kPa];
        }
        
        port waterSource : WaterInletPort;
        port waterDelivery : WaterDischargePort;
        port steamExhaustVent : SteamExhaustPort;
        
        connection steamSupplyLine connect boiler.steamOutput to steamCylinder.steamIn;
        connection mechanicalDrive connect steamCylinder.powerOut to reciprocatingPump.powerIn;
        connection steamExhaustLine connect steamCylinder.steamOut to condenser.steamIn;
        connection suctionLine connect waterSource to suctionValve.inlet;
        connection pumpInlet connect suctionValve.outlet to reciprocatingPump.waterIn;
        connection pumpOutlet connect reciprocatingPump.waterOut to dischargeValve.inlet;
        connection deliveryLine connect dischargeValve.outlet to waterDelivery;
        connection exhaustVent connect condenser.condensateOut to steamExhaustVent;
        
        perform action operateSteamPump {
            first start;
            then merge continuousOperation;
            
            action generateSteam : boiler.produceSteam {
                out steam : SteamFlow;
            }
            then generateSteam;
            
            action convertEnergy : steamCylinder.convertSteamToPower {
                in highPressureSteam = generateSteam.steam;
                out mechanicalOutput : MechanicalWork;
                out exhaustedSteam : SteamFlow;
            }
            then convertEnergy;
            
            action pumpFluid : reciprocatingPump.pumpWater {
                in drivePower = convertEnergy.mechanicalOutput;
                in inletWater : WaterFlow;
                out dischargedWater : WaterFlow;
            }
            then pumpFluid;
            
            action monitorPressure : dischargePressureGauge.measurePressure {
                out pressureReading : ISQ::pressure;
            }
            then monitorPressure;
            
            action monitorFlow : flowMeter.measureFlow {
                out flowReading : ISQ::volumeFlowRate;
            }
            then monitorFlow;
            
            then decide;
                if monitorPressure.pressureReading < designPressure then continuousOperation;
                if monitorPressure.pressureReading >= designPressure then regulateSteam;
            
            action regulateSteam {
                in currentPressure = monitorPressure.pressureReading;
                out adjustedSteamFlow : ISQ::massFlowRate;
            }
            then continuousOperation;
            
            action condenseExhaust : condenser.condenseSteam {
                in exhaustSteam = convertEnergy.exhaustedSteam;
                out condensedWater : WaterFlow;
            }
            then continuousOperation;
        }
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* 
            The steam pump system shall convert thermal energy from high-pressure steam 
            into mechanical work to drive a reciprocating pump that transfers water from 
            a low-pressure source to a high-pressure destination.
        */
        
        subject steamPump : SteamPump;
        
        require constraint steamConversionCapability {
            steamPump.steamCylinder.convertSteamToPower.mechanicalOutput.power >= 10.0 [SI::kW]
        }
        
        require constraint waterPumpingCapability {
            steamPump.reciprocatingPump.pumpWater.dischargedWater.volumeFlowRate >= 0.05 [SI::m^3/SI::s]
        }
    }
    
    requirement def PerformanceRequirement {
        doc /* 
            The steam pump shall deliver water at the specified flow rate and pressure 
            with acceptable efficiency under normal operating conditions.
        */
        
        subject steamPump : SteamPump;
        
        require constraint minimumFlowRate {
            steamPump.reciprocatingPump.pumpWater.dischargedWater.volumeFlowRate >= 0.05 [SI::m^3/SI::s]
        }
        
        require constraint minimumDischargePressure {
            steamPump.reciprocatingPump.dischargePressure >= 700.0 [SI::kPa]
        }
        
        require constraint minimumEfficiency {
            steamPump.overallEfficiency >= 0.60
        }
    }
    
    requirement def SafetyRequirement {
        doc /* 
            The steam pump system shall operate safely within specified pressure and 
            temperature limits and shall include safety devices to prevent overpressure conditions.
        */
        
        subject steamPump : SteamPump;
        
        require constraint maximumSteamPressure {
            steamPump.boiler.operatingPressure <= 1100.0 [SI::kPa]
        }
        
        require constraint safetyValvePresent {
            steamPump.safetyValve.reliefPressure <= 1200.0 [SI::kPa]
        }
        
        require constraint maximumTemperature {
            steamPump.boiler.operatingTemperature <= 473.15 [SI::K]
        }
    }
    
    requirement def ReliabilityRequirement {
        doc /* 
            The steam pump system shall maintain continuous operation with minimal 
            maintenance requirements and shall handle varying load conditions.
        */
        
        subject steamPump : SteamPump;
        
        attribute meanTimeBetweenMaintenance :> ISQ::time;
        attribute operationalAvailability : ScalarValues::Real;
        
        require constraint availabilityTarget {
            operationalAvailability >= 0.90
        }
        
        require constraint maintenanceInterval {
            meanTimeBetweenMaintenance >= 720.0 [SI::h]
        }
    }
    
    requirement <'SP-SYS-001'> steamPumpSystemRequirements {
        doc /* 
            The steam pump system shall provide reliable water pumping capability by 
            converting steam energy into mechanical work. The system shall operate 
            efficiently, safely, and continuously under specified operating conditions 
            to transfer water from a source at low pressure to a destination at elevated pressure.
        */
        
        subject steamPumpInstance : SteamPump;
        
        require primaryFunctionReq : PrimaryFunctionRequirement;
        require performanceReq : PerformanceRequirement;
        require safetyReq : SafetyRequirement;
        require reliabilityReq : ReliabilityRequirement;
    }
    
    part steamPumpInstance : SteamPump {
        attribute :>> designPressure = 800.0 [SI::kPa];
        attribute :>> designFlowRate = 0.06 [SI::m^3/SI::s];
        attribute :>> overallEfficiency = 0.65;
    }
    
    satisfy steamPumpSystemRequirements by steamPumpInstance;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import SteamPumpSystem::*;

    part testSubject : SteamPump;

    part testSubject : SteamCylinder {
        exhibit state sm : SteamPumpOperatingStates;
    }
}
