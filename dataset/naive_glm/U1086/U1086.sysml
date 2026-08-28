package AutonomousPlanetaryDrillingSystem {
    imports ScalarValues::*;
    imports ISQ::*;

    // ---- Value Types with Units ----
    value type TemperatureValue > Real { unit 'degC'; }
    value type PowerValue > Real { unit 'W'; }
    value type DepthValue > Real { unit 'cm'; }
    value type MassValue > Real { unit 'g'; }
    value type TorqueValue > Real { unit 'N*m'; }
    value type RotationalSpeedValue > Real { unit 'rpm'; }
    value type ForceValue > Real { unit 'N'; }
    value type VoltageValue > Real { unit 'V'; }
    value type CurrentValue > Real { unit 'A'; }
    value type PercentValue > Real { unit '%'; }

    // ---- Item Definitions ----
    item def Power {
        :>> voltage : VoltageValue;
        :>> current : CurrentValue;
        :>> power : PowerValue = voltage * current;
    }

    item def RegolithSample {
        :>> mass : MassValue;
        :>> pristine : Boolean = true;
        :>> originDepth : DepthValue;
    }

    item def CommandSignal {
        attribute commandKind : CommandKind;
        attribute targetDepth : DepthValue;
        attribute heaterLevel : PercentValue;
    }

    enum def CommandKind { deploy; startDrilling; stopDrilling; retract; transferSample; seal; emergencyStop; }

    item def StatusReport {
        attribute healthy : Boolean;
        attribute temperature : TemperatureValue;
        attribute depth : DepthValue;
        attribute powerDraw : PowerValue;
        attribute sampleMass : MassValue;
    }

    enum def CacheContainerState { empty; filling; filled; sealed; }

    // ---- Port Definitions ----
    port def PowerPort {
        out power : Power;
    }

    port def CommandPort {
        in command : CommandSignal;
        out status : StatusReport;
    }

    port def MechanicalPort {
        out force : ForceValue;
        out position : DepthValue;
    }

    port def RotationPort {
        out torque : TorqueValue;
        out speed : RotationalSpeedValue;
    }

    port def SamplePort {
        out sample : RegolithSample;
    }

    port def ThermalPort {
        out temperature : TemperatureValue;
        in heaterLevel : PercentValue;
    }

    // ---- Requirements ----
    requirement def OperationalTemperatureRange {
        doc { The system shall operate in ambient temperatures from -150 degC to +70 degC. }
        subject temp : TemperatureValue;
        constraint { temp >= -150 and temp <= 70 }
    }

    requirement def PowerBudgetRequirement {
        doc { The system shall consume no more than 150 W during drilling. }
        subject power : PowerValue;
        constraint { power <= 150 }
    }

    requirement def DrillingDepthRequirement {
        doc { The system shall drill between 5 cm and 100 cm depth. }
        subject depth : DepthValue;
        constraint { depth >= 5 and depth <= 100 }
    }

    requirement def SampleMassRequirement {
        doc { The system shall collect at least 30 g of sample per operation. }
        subject sampleMass : MassValue;
        constraint { sampleMass >= 30 }
    }

    requirement def SamplePreservationRequirement {
        doc { The collected sample shall remain pristine and uncontaminated. }
        subject sample : RegolithSample;
        constraint { sample.pristine == true }
    }

    requirement def AutonomousOperationRequirement {
        doc { The system shall perform a complete drilling operation autonomously. }
        subject system : PlanetaryDrillingSystem;
        constraint { system.controller.autonomous == true }
    }

    // ---- Component Parts ----

    part def ControllerUnit {
        port powerIn : PowerPort;
        port commandIn : CommandPort;
        port actuatorCommandOut : CommandPort;
        port motorCommandOut : CommandPort;
        port cacheCommandOut : CommandPort;
        port thermalCommandOut : CommandPort;
        port actuatorStatusIn : CommandPort;
        port motorStatusIn : CommandPort;
        port cacheStatusIn : CommandPort;
        port thermalStatusIn : CommandPort;

        attribute autonomous : Boolean = true;
        attribute targetDepth : DepthValue = 50;
        attribute maxPower : PowerValue = 150;
        attribute currentDepth : DepthValue = 0;
        attribute currentTemp : TemperatureValue = 20;
        attribute faultDetected : Boolean = false;

        state machine ControllerBehavior {
            entry; then stowed;

            state stowed {
                entry { /* initialize subsystems */ }
            }
            transition from stowed to deploying
                when commandIn.command?.commandKind == CommandKind::deploy;

            state deploying {
                entry { /* send deploy command to actuator */ }
            }
            transition from deploying to drilling
                when actuatorStatusIn.status?.depth > 0;

            state drilling {
                entry { /* start drill motor, monitor depth and temperature */ }
                do { monitorHealth(); }
            }
            transition from drilling to retracting
                when currentDepth >= targetDepth;
            transition from drilling to faulted
                when faultDetected or currentTemp > 70 or currentTemp < -150;

            state retracting {
                entry { /* stop motor, retract actuator */ }
            }
            transition from retracting to caching
                when actuatorStatusIn.status?.depth == 0;

            state caching {
                entry { /* transfer sample to cache, seal container */ }
            }
            transition from caching to stowed
                when cacheStatusIn.status?.healthy == true;

            state faulted {
                entry { /* emergency stop all actuators and motors */ }
            }
        }

        action monitorHealth {
            in temp : TemperatureValue;
            in power : PowerValue;
            out healthy : Boolean;
        }
    }

    part def PowerDistributionUnit {
        port mainPowerIn : PowerPort;
        port controllerPowerOut : PowerPort;
        port motorPowerOut : PowerPort;
        port actuatorPowerOut : PowerPort;
        port heaterPowerOut : PowerPort;

        attribute totalPower : PowerValue;
        attribute maxPower : PowerValue = 150;

        action distributePower {
            in mainPower : Power;
            out toController : Power;
            out toMotor : Power;
            out toActuator : Power;
            out toHeater : Power;
        }

        action regulate {
            in demand : PowerValue;
            out allocated : PowerValue;
        }
    }

    part def LinearActuator {
        port powerIn : PowerPort;
        port commandIn : CommandPort;
        port mechanicalOut : MechanicalPort;
        port statusOut : CommandPort;

        attribute maxForce : ForceValue = 200;
        attribute currentDepth : DepthValue = 0;
        attribute deployed : Boolean = false;
        attribute targetDepth : DepthValue;

        action deploy {
            out force : ForceValue;
            out position : DepthValue;
        }

        action pushDown {
            in target : DepthValue;
            out depth : DepthValue;
        }

        action retract {
            out position : DepthValue;
        }
    }

    part def DrillMotorAssembly {
        port powerIn : PowerPort;
        port commandIn : CommandPort;
        port rotationOut : RotationPort;
        port statusOut : CommandPort;

        attribute nominalTorque : TorqueValue = 5;
        attribute nominalSpeed : RotationalSpeedValue = 500;
        attribute active : Boolean = false;
        attribute powerDraw : PowerValue;

        action rotate {
            in command : CommandSignal;
            out torque : TorqueValue;
            out speed : RotationalSpeedValue;
        }

        action stop {
            out torque : TorqueValue = 0;
            out speed : RotationalSpeedValue = 0;
        }
    }

    part def DrillBitAssembly {
        port rotationIn : RotationPort;
        port mechanicalIn : MechanicalPort;
        port sampleOut : SamplePort;

        attribute tipMaterial : String = "carbide";
        attribute fluted : Boolean = true;
        attribute capturedSample : RegolithSample;

        action cut {
            in torque : TorqueValue;
            in force : ForceValue;
            out sample : RegolithSample;
        }

        action ejectSample {
            out sample : RegolithSample;
        }
    }

    part def SampleCacheSystem {
        port powerIn : PowerPort;
        port commandIn : CommandPort;
        port sampleIn : SamplePort;
        port statusOut : CommandPort;

        attribute containerCount : Integer = 12;
        attribute containers : CacheContainerState[12] = ( #empty, #empty, #empty, #empty, #empty, #empty, #empty, #empty, #empty, #empty, #empty, #empty );
        attribute currentIndex : Integer = 0;
        attribute sealedCount : Integer = 0;

        action transferSample {
            in sample : RegolithSample;
            // place sample into current container
        }

        action sealContainer {
            // hermetically seal current container, advance index
        }

        action advanceContainer;
    }

    part def ThermalManagementSystem {
        port powerIn : PowerPort;
        port commandIn : CommandPort;
        port thermalOut : ThermalPort;
        port statusOut : CommandPort;

        attribute currentTemp : TemperatureValue = 20;
        attribute targetTemp : TemperatureValue = 20;
        attribute heaterActive : Boolean = false;
        attribute heaterLevel : PercentValue = 0;
        attribute minOperatingTemp : TemperatureValue = -150;
        attribute maxOperatingTemp : TemperatureValue = 70;

        action monitorTemperature {
            out temp : TemperatureValue;
        }

        action activateHeater {
            in level : PercentValue;
            out heatLevel : PercentValue;
        }

        action deactivateHeater {
            out heatLevel : PercentValue = 0;
        }

        state machine ThermalControl {
            entry; then monitoring;

            state monitoring {
                do { monitorTemperature(); }
            }
            transition from monitoring to heating
                when currentTemp < targetTemp - 5;

            state heating {
                entry { activateHeater(100); }
                do { monitorTemperature(); }
            }
            transition from heating to monitoring
                when currentTemp >= targetTemp;

            transition from monitoring to cooling
                when currentTemp > maxOperatingTemp - 5;

            state cooling {
                entry { deactivateHeater(); }
                do { monitorTemperature(); }
            }
            transition from cooling to monitoring
                when currentTemp <= targetTemp;
        }
    }

    // ---- Top-Level System ----
    part def PlanetaryDrillingSystem {
        doc { Autonomous planetary drilling system for acquiring and preserving geological samples on Mars or the Moon. }

        port externalPower : PowerPort;
        port externalCommand : CommandPort;

        // Satisfies requirements
        satisfy OperationalTemperatureRange by temp : thermal.currentTemp;
        satisfy PowerBudgetRequirement by power : pdu.totalPower;
        satisfy DrillingDepthRequirement by depth : controller.currentDepth;
        satisfy SampleMassRequirement by sampleMass : drillBit.capturedSample.mass;
        satisfy SamplePreservationRequirement by sample : drillBit.capturedSample;
        satisfy AutonomousOperationRequirement by system : self;

        part controller : ControllerUnit {
            :>> targetDepth : DepthValue = 50;
        }
        part pdu : PowerDistributionUnit;
        part actuator : LinearActuator;
        part drillMotor : DrillMotorAssembly;
        part drillBit : DrillBitAssembly;
        part cache : SampleCacheSystem;
        part thermal : ThermalManagementSystem;

        // Power distribution
        connect externalPower to pdu.mainPowerIn;
        connect pdu.controllerPowerOut to controller.powerIn;
        connect pdu.motorPowerOut to drillMotor.powerIn;
        connect pdu.actuatorPowerOut to actuator.powerIn;
        connect pdu.heaterPowerOut to thermal.powerIn;
        connect pdu.heaterPowerOut to cache.powerIn;

        // External command to controller
        connect externalCommand to controller.commandIn;

        // Controller commands to subsystems
        connect controller.actuatorCommandOut to actuator.commandIn;
        connect controller.motorCommandOut to drillMotor.commandIn;
        connect controller.cacheCommandOut to cache.commandIn;
        connect controller.thermalCommandOut to thermal.commandIn;

        // Status feedback to controller
        connect actuator.statusOut to controller.actuatorStatusIn;
        connect drillMotor.statusOut to controller.motorStatusIn;
        connect cache.statusOut to controller.cacheStatusIn;
        connect thermal.statusOut to controller.thermalStatusIn;

        // Mechanical and rotational interfaces
        connect actuator.mechanicalOut to drillBit.mechanicalIn;
        connect drillMotor.rotationOut to drillBit.rotationIn;

        // Sample transfer
        connect drillBit.sampleOut to cache.sampleIn;

        // Thermal monitoring
        connect thermal.thermalOut to controller.thermalStatusIn;

        // System-level behavior
        state machine MissionSequence {
            entry; then stowed;

            state stowed;
            transition from stowed to deployed
                when externalCommand.command?.commandKind == CommandKind::deploy;

            state deployed;
            transition from deployed to drilling
                when actuator.deployed == true;

            state drilling;
            transition from drilling to retracted
                when controller.currentDepth >= controller.targetDepth;

            state retracted;
            transition from retracted to sampleCaching
                when actuator.currentDepth == 0;

            state sampleCaching;
            transition from sampleCaching to missionComplete
                when cache.sealedCount > 0;

            state missionComplete;
        }
    }
}
