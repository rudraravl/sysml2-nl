package 'Spacecraft Solar Power System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SolarIrradiance :> Real {
        doc /* Solar irradiance measured in watts per square meter */
    }
    
    attribute def Efficiency :> Real {
        doc /* Dimensionless efficiency ratio between 0 and 1 */
    }
    
    attribute def StateOfCharge :> Real {
        doc /* Battery state of charge as percentage 0-100 */
    }
    
    attribute def Voltage :> ISQ::ElectricPotentialValue;
    attribute def Current :> ISQ::ElectricCurrentValue;
    attribute def Power :> ISQ::PowerValue;
    attribute def Energy :> ISQ::EnergyValue;
    attribute def Area :> ISQ::AreaValue;
    attribute def Temperature :> ISQ::ThermodynamicTemperatureValue;
    attribute def Angle :> ISQ::PlaneAngleValue;
    
    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : Power;
    }
    
    item def SunVector {
        attribute azimuth : Angle;
        attribute elevation : Angle;
        attribute intensity : SolarIrradiance;
    }
    
    item def OrientationCommand {
        attribute targetAzimuth : Angle;
        attribute targetElevation : Angle;
    }
    
    port def ElectricalPort {
        out item electricalPower : ElectricalPower;
    }
    
    port def SensorPort {
        out item sunData : SunVector;
    }
    
    port def CommandPort {
        in item orientationCmd : OrientationCommand;
    }
    
    part def SolarCell {
        attribute cellArea : Area;
        attribute baseEfficiency : Efficiency;
        attribute operatingTemp : Temperature;
        
        action def ConvertLight {
            in irradiance : SolarIrradiance;
            in area : Area;
            in efficiency : Efficiency;
            in incidenceAngle : Angle;
            out generatedPower : Power;
        }
    }
    
    part def SolarPanel {
        attribute panelArea : Area;
        attribute numberOfCells : Integer;
        attribute panelEfficiency : Efficiency;
        attribute currentTemperature : Temperature;
        
        part cells : SolarCell[32];
        
        port powerOutput : ElectricalPort;
        
        action def GeneratePanelPower {
            in irradiance : SolarIrradiance;
            in angle : Angle;
            out panelPower : Power;
        }
    }
    
    part def SolarArray {
        attribute totalArea : Area;
        attribute arrayEfficiency : Efficiency;
        attribute deployed : Boolean;
        
        part panels : SolarPanel[4];
        
        port arrayPowerOut : ElectricalPort;
        port gimbalControl : CommandPort;
        
        action def DeployArray {
            out deploymentStatus : Boolean;
        }
        
        action def AggregateArrayPower {
            in panelPowers : Power[*];
            out totalPower : Power;
        }
    }
    
    part def SunSensor {
        attribute measurementAccuracy : Angle;
        
        port sensorOutput : SensorPort;
        
        action def MeasureSunPosition {
            out sunVector : SunVector;
        }
    }
    
    part def GimbalActuator {
        attribute currentAzimuth : Angle;
        attribute currentElevation : Angle;
        attribute maxRotationRate : Real;
        
        port controlInput : CommandPort;
        
        action def OrientArray {
            in command : OrientationCommand;
            out actualAzimuth : Angle;
            out actualElevation : Angle;
        }
    }
    
    part def AttitudeController {
        port sunSensorInput : SensorPort;
        port gimbalCommandOutput : CommandPort;
        
        action def CalculateOrientation {
            in sunVector : SunVector;
            in currentAzimuth : Angle;
            in currentElevation : Angle;
            out orientationCommand : OrientationCommand;
        }
        
        action def TrackSun {
            in sunData : SunVector;
            out trackingCommand : OrientationCommand;
        }
    }
    
    part def PowerRegulator {
        attribute regulatedVoltage : Voltage;
        attribute maxCurrent : Current;
        
        port inputPort : ElectricalPort;
        port outputPort : ElectricalPort;
        
        action def RegulateVoltage {
            in inputVoltage : Voltage;
            in inputCurrent : Current;
            in setpoint : Voltage;
            out outputVoltage : Voltage;
            out outputCurrent : Current;
        }
    }
    
    part def Battery {
        attribute capacity : Energy;
        attribute stateOfCharge : StateOfCharge;
        attribute nominalVoltage : Voltage;
        attribute maxChargeRate : Power;
        attribute maxDischargeRate : Power;
        
        port batteryPort : ElectricalPort;
        
        action def ChargeDischarge {
            in powerFlow : Power;
            in currentSOC : StateOfCharge;
            in deltaTime : ISQ::DurationValue;
            out newSOC : StateOfCharge;
        }
    }
    
    part def PowerDistributionUnit {
        attribute busVoltage : Voltage;
        
        port solarInput : ElectricalPort;
        port batteryPort : ElectricalPort;
        port loadBus1 : ElectricalPort;
        port loadBus2 : ElectricalPort;
        port loadBus3 : ElectricalPort;
        
        action def ManagePowerFlow {
            in solarPower : Power;
            in batterySOC : StateOfCharge;
            in loadDemand1 : Power;
            in loadDemand2 : Power;
            in loadDemand3 : Power;
            out powerToBattery : Power;
            out powerToLoad1 : Power;
            out powerToLoad2 : Power;
            out powerToLoad3 : Power;
        }
    }
    
    part def SpacecraftLoad {
        attribute powerDemand : Power;
        attribute priority : Integer;
        
        port powerInput : ElectricalPort;
    }
    
    action def GenerateSolarPower {
        in irradiance : SolarIrradiance;
        in arrayArea : Area;
        in efficiency : Efficiency;
        in sunAngle : Angle;
        out electricalPower : Power;
    }
    
    action def OrientToSun {
        in sunPosition : SunVector;
        in currentOrientation : OrientationCommand;
        out newOrientation : OrientationCommand;
    }
    
    action def DistributePower {
        in availablePower : Power;
        in batteryCharge : StateOfCharge;
        in demands : Power[*];
        out allocations : Power[*];
        out batteryPower : Power;
    }
    
    attribute def DeployComplete;
    attribute def SunAcquired;
    attribute def EnterEclipse;
    attribute def ExitEclipse;
    attribute def SystemFault;
    
    state machine PowerSystemStates {
        initial state Stowed;
        
        state Deploying {
            entry action deployArrays;
        }
        
        state SunAcquisition {
            entry action searchForSun;
        }
        
        state NominalOperation {
            do action trackAndGenerate;
        }
        
        state Eclipse {
            do action batteryDischarge;
        }
        
        state SafeMode {
            entry action minimizePower;
        }
        
        transition stowedToDeploying
            first Stowed
            then Deploying;
        
        transition deployingToAcquisition
            first Deploying
            accept deployComplete : DeployComplete
            then SunAcquisition;
        
        transition acquisitionToNominal
            first SunAcquisition
            accept sunAcquired : SunAcquired
            then NominalOperation;
        
        transition nominalToEclipse
            first NominalOperation
            accept enterEclipse : EnterEclipse
            then Eclipse;
        
        transition eclipseToNominal
            first Eclipse
            accept exitEclipse : ExitEclipse
            then NominalOperation;
        
        transition anyToSafe
            first Deploying
            accept systemFault : SystemFault
            then SafeMode;
    }
    
    action def OperateSolarPowerSystem {
        in irradianceProfile : SolarIrradiance[*];
        in sunVectorProfile : SunVector[*];
        in loadDemandProfile : Power[*];
        in initialBatterySOC : StateOfCharge;
        in arrayArea : Area;
        in arrayEfficiency : Efficiency;
        in batteryCapacity : Energy;
        in regulatedVoltage : Voltage;
        
        out socHistory : StateOfCharge[*] := ( );
        out powerHistory : Power[*] := ( );
        
        private attribute batterySOC := initialBatterySOC;
        private attribute currentOrientation : OrientationCommand;
        
        first start;
        then merge operationLoop;
        
        then for idx in 1..100 {
            action senseSun {
                in sunVector : SunVector := sunVectorProfile->at(idx);
                out measuredSun : SunVector;
            }
            
            then action calculateOrientation : OrientToSun {
                in sunPosition = senseSun.measuredSun;
                in currentOrientation = OperateSolarPowerSystem::currentOrientation;
                out newOrientation : OrientationCommand;
            }
            
            then assign currentOrientation := calculateOrientation.newOrientation;
            
            then action generatePower : GenerateSolarPower {
                in irradiance = irradianceProfile->at(idx);
                in arrayArea = OperateSolarPowerSystem::arrayArea;
                in efficiency = OperateSolarPowerSystem::arrayEfficiency;
                in sunAngle = calculateOrientation.newOrientation.targetElevation;
                out electricalPower : Power;
            }
            
            then action distributePower : DistributePower {
                in availablePower = generatePower.electricalPower;
                in batteryCharge = batterySOC;
                in demands = loadDemandProfile;
                out allocations : Power[*];
                out batteryPower : Power;
            }
            
            then decide;
                if distributePower.batteryPower > 0.0 then chargeBattery;
                if distributePower.batteryPower < 0.0 then dischargeBattery;
                else maintainBattery;
            
            action chargeBattery {
                then assign batterySOC := batterySOC + 0.5;
            }
            
            action dischargeBattery {
                then assign batterySOC := batterySOC - 0.5;
            }
            
            action maintainBattery;
            
            then assign socHistory := socHistory->including(batterySOC);
            then assign powerHistory := powerHistory->including(generatePower.electricalPower);
        }
        
        then operationLoop;
    }
    
    part spacecraftPowerSystem {
        doc /* 
            The spacecraft solar power system converts sunlight into electrical energy
            to power all spacecraft subsystems and charge batteries for eclipse operations.
            The system autonomously tracks the sun, maximizes power generation through
            optimal panel orientation, regulates voltage for spacecraft buses, and manages
            energy storage to ensure continuous power availability throughout all mission phases.
        */
        
        attribute solarIrradiance : SolarIrradiance = 1361.0;
        attribute totalPowerDemand : Power;
        
        part solarArray : SolarArray {
            attribute :>> totalArea = 16.0 [m^2];
            attribute :>> arrayEfficiency = 0.29;
            attribute :>> deployed = false;
        }
        
        part sunSensor : SunSensor {
            attribute :>> measurementAccuracy = 0.1 [rad];
        }
        
        part gimbal : GimbalActuator {
            attribute :>> maxRotationRate = 2.0;
        }
        
        part attitudeControl : AttitudeController;
        
        part regulator : PowerRegulator {
            attribute :>> regulatedVoltage = 28.0 [V];
            attribute :>> maxCurrent = 100.0 [A];
        }
        
        part battery : Battery {
            attribute :>> capacity = 36000000.0 [J];
            attribute :>> stateOfCharge = 80.0;
            attribute :>> nominalVoltage = 28.0 [V];
            attribute :>> maxChargeRate = 1000.0 [W];
            attribute :>> maxDischargeRate = 1500.0 [W];
        }
        
        part pdu : PowerDistributionUnit {
            attribute :>> busVoltage = 28.0 [V];
        }
        
        part communicationsLoad : SpacecraftLoad {
            attribute :>> powerDemand = 800.0 [W];
            attribute :>> priority = 1;
        }
        
        part payloadLoad : SpacecraftLoad {
            attribute :>> powerDemand = 1200.0 [W];
            attribute :>> priority = 2;
        }
        
        part thermalLoad : SpacecraftLoad {
            attribute :>> powerDemand = 500.0 [W];
            attribute :>> priority = 3;
        }
        
        connection sensorToController connect 
            sunSensor.sensorOutput to attitudeControl.sunSensorInput;
        
        connection controllerToGimbal connect 
            attitudeControl.gimbalCommandOutput to gimbal.controlInput;
        
        connection gimbalToArray connect 
            gimbal.controlInput to solarArray.gimbalControl;
        
        connection arrayToRegulator connect 
            solarArray.arrayPowerOut to regulator.inputPort;
        
        connection regulatorToPDU connect 
            regulator.outputPort to pdu.solarInput;
        
        connection pduToBattery connect 
            pdu.batteryPort to battery.batteryPort;
        
        connection pduToComms connect 
            pdu.loadBus1 to communicationsLoad.powerInput;
        
        connection pduToPayload connect 
            pdu.loadBus2 to payloadLoad.powerInput;
        
        connection pduToThermal connect 
            pdu.loadBus3 to thermalLoad.powerInput;
        
        exhibit state systemState : PowerSystemStates;
        
        perform action operatePowerSystem : OperateSolarPowerSystem;
    }
    
    requirement <'SPR-001'> powerGenerationRequirement {
        doc /* 
            The solar power system shall generate minimum 3000 W of electrical power
            at beginning of life when oriented normal to the sun at 1 AU.
        */
        
        subject spacecraftPowerSystem.solarArray;
        
        require constraint {
            spacecraftPowerSystem.solarArray.totalArea * 
            spacecraftPowerSystem.solarArray.arrayEfficiency * 
            spacecraftPowerSystem.solarIrradiance >= 3000.0
        }
    }
    
    requirement <'SPR-002'> sunTrackingRequirement {
        doc /* 
            The solar array shall maintain pointing accuracy within 2 degrees
            of the sun vector during all sunlit operations.
        */
        
        subject spacecraftPowerSystem.attitudeControl;
    }
    
    requirement <'SPR-003'> voltageRegulationRequirement {
        doc /* 
            The power regulation system shall maintain bus voltage at 28V +/- 0.5V
            under all load conditions.
        */
        
        subject spacecraftPowerSystem.regulator;
        
        require constraint {
            spacecraftPowerSystem.regulator.regulatedVoltage >= 27.5 [V] and
            spacecraftPowerSystem.regulator.regulatedVoltage <= 28.5 [V]
        }
    }
    
    requirement <'SPR-004'> eclipseOperationRequirement {
        doc /* 
            The battery system shall provide minimum 1500 W continuous power
            for 90 minutes during maximum eclipse duration.
        */
        
        subject spacecraftPowerSystem.battery;
        
        require constraint {
            spacecraftPowerSystem.battery.capacity >= 8100000.0 [J] and
            spacecraftPowerSystem.battery.maxDischargeRate >= 1500.0 [W]
        }
    }
    
    requirement <'SPR-005'> powerDistributionRequirement {
        doc /* 
            The power distribution unit shall allocate power to loads based on
            priority and available power, ensuring critical systems remain powered.
        */
        
        subject spacecraftPowerSystem.pdu;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Spacecraft Solar Power System'::*;

    action orchestrator {
        attribute testIrradiance : SolarIrradiance = 0.0;
        attribute testArea : Area;
        attribute testEfficiency : Efficiency = 0.0;
        attribute testIncidenceAngle : Angle;
        action actionProbe : ConvertLight {
            in irradiance = testIrradiance;
            in area = testArea;
            in efficiency = testEfficiency;
            in incidenceAngle = testIncidenceAngle;
        }
        first actionProbe;
    }
}
