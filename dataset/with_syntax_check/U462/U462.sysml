package 'Affinity Laws Pumping System' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def SpeedRatio :> Real;
    attribute def DiameterRatio :> Real;
    
    item def ProcessFluid {
        attribute density :> ISQ::density;
        attribute viscosity :> ISQ::dynamicViscosity;
        attribute temperature :> ISQ::thermodynamicTemperature;
    }
    
    part def PumpPerformanceCurve {
        attribute referenceSpeed :> ISQ::angularVelocity;
        attribute referenceFlowRate :> ISQ::volumeFlowRate;
        attribute referenceHead :> ISQ::length;
        attribute referencePower :> ISQ::power;
        attribute impellerDiameter :> ISQ::length;
    }
    
    port def FluidPort {
        attribute flowRate :> ISQ::volumeFlowRate;
        attribute pressure :> ISQ::pressure;
        attribute temperature :> ISQ::thermodynamicTemperature;
    }
    
    port def MechanicalPort {
        attribute speed :> ISQ::angularVelocity;
        attribute torque :> ISQ::torque;
        attribute power :> ISQ::power;
    }
    
    port def ControlPort {
        attribute speedSetpoint :> ISQ::angularVelocity;
        attribute speedFeedback :> ISQ::angularVelocity;
        attribute powerFeedback :> ISQ::power;
    }
    
    action def CalculateFlowByAffinityLaw1 {
        doc /* First Affinity Law: Flow rate varies directly with speed ratio */
        in referenceFlow :> ISQ::volumeFlowRate;
        in referenceSpeed :> ISQ::angularVelocity;
        in actualSpeed :> ISQ::angularVelocity;
        out actualFlow :> ISQ::volumeFlowRate;
    }
    
    action def CalculateHeadByAffinityLaw2 {
        doc /* Second Affinity Law: Head varies with square of speed ratio */
        in referenceHead :> ISQ::length;
        in referenceSpeed :> ISQ::angularVelocity;
        in actualSpeed :> ISQ::angularVelocity;
        out actualHead :> ISQ::length;
    }
    
    action def CalculatePowerByAffinityLaw3 {
        doc /* Third Affinity Law: Power varies with cube of speed ratio */
        in referencePower :> ISQ::power;
        in referenceSpeed :> ISQ::angularVelocity;
        in actualSpeed :> ISQ::angularVelocity;
        out actualPower :> ISQ::power;
    }
    
    action def CalculateDiameterEffectOnFlow {
        doc /* Flow varies directly with diameter ratio */
        in referenceFlow :> ISQ::volumeFlowRate;
        in referenceDiameter :> ISQ::length;
        in actualDiameter :> ISQ::length;
        out actualFlow :> ISQ::volumeFlowRate;
    }
    
    action def CalculateDiameterEffectOnHead {
        doc /* Head varies with square of diameter ratio */
        in referenceHead :> ISQ::length;
        in referenceDiameter :> ISQ::length;
        in actualDiameter :> ISQ::length;
        out actualHead :> ISQ::length;
    }
    
    action def CalculateDiameterEffectOnPower {
        doc /* Power varies with fifth power of diameter ratio */
        in referencePower :> ISQ::power;
        in referenceDiameter :> ISQ::length;
        in actualDiameter :> ISQ::length;
        out actualPower :> ISQ::power;
    }
    
    part def CentrifugalPump {
        attribute pumpIdentifier :> ScalarValues::String;
        
        port suctionPort : FluidPort;
        port dischargePort : FluidPort;
        port shaftPort : MechanicalPort;
        
        part performanceCurve : PumpPerformanceCurve {
            attribute :>> referenceSpeed = 188.5 [SI::'rad/s'];
            attribute :>> referenceFlowRate = 0.1 [SI::'m^3/s'];
            attribute :>> referenceHead = 50.0 [SI::m];
            attribute :>> referencePower = 75000.0 [SI::W];
            attribute :>> impellerDiameter = 0.4 [SI::m];
        }
        
        perform action pumpOperation : PumpHydraulicBehavior;
    }
    
    action def PumpHydraulicBehavior {
        in operatingSpeed :> ISQ::angularVelocity;
        in performanceData : PumpPerformanceCurve;
        out deliveredFlow :> ISQ::volumeFlowRate;
        out developedHead :> ISQ::length;
        out requiredPower :> ISQ::power;
        
        action calculateFlow : CalculateFlowByAffinityLaw1 {
            in referenceFlow = PumpHydraulicBehavior::performanceData.referenceFlowRate;
            in referenceSpeed = PumpHydraulicBehavior::performanceData.referenceSpeed;
            in actualSpeed = PumpHydraulicBehavior::operatingSpeed;
            out actualFlow;
        }
        
        action calculateHead : CalculateHeadByAffinityLaw2 {
            in referenceHead = PumpHydraulicBehavior::performanceData.referenceHead;
            in referenceSpeed = PumpHydraulicBehavior::performanceData.referenceSpeed;
            in actualSpeed = PumpHydraulicBehavior::operatingSpeed;
            out actualHead;
        }
        
        action calculatePower : CalculatePowerByAffinityLaw3 {
            in referencePower = PumpHydraulicBehavior::performanceData.referencePower;
            in referenceSpeed = PumpHydraulicBehavior::performanceData.referenceSpeed;
            in actualSpeed = PumpHydraulicBehavior::operatingSpeed;
            out actualPower;
        }
    }
    
    part def VariableFrequencyDrive {
        attribute driveIdentifier :> ScalarValues::String;
        attribute outputFrequency :> ISQ::frequency;
        attribute outputVoltage :> ISQ::voltage;
        attribute maxFrequency :> ISQ::frequency;
        attribute minFrequency :> ISQ::frequency;
        
        port controlInput : ControlPort;
        port motorOutput : MechanicalPort;
        
        perform action driveControl : VFDControlBehavior;
    }
    
    action def VFDControlBehavior {
        in speedCommand :> ISQ::angularVelocity;
        in maxFreq :> ISQ::frequency;
        in minFreq :> ISQ::frequency;
        out motorSpeed :> ISQ::angularVelocity;
        out motorTorque :> ISQ::torque;
        
        action validateCommand {
            in command :> ISQ::angularVelocity;
            in maxLimit :> ISQ::frequency;
            in minLimit :> ISQ::frequency;
            out validatedSpeed :> ISQ::angularVelocity;
        }
        
        action generateOutput {
            in targetSpeed :> ISQ::angularVelocity;
            out outputSpeed :> ISQ::angularVelocity;
            out outputTorque :> ISQ::torque;
        }
    }
    
    part def FlowTransmitter {
        attribute transmitterTag :> ScalarValues::String;
        attribute measurementAccuracy :> Real;
        
        port processConnection : FluidPort;
        port signalOutput {
            attribute measuredFlow :> ISQ::volumeFlowRate;
        }
        
        perform action measureFlow : FlowMeasurement;
    }
    
    action def FlowMeasurement {
        in actualFlow :> ISQ::volumeFlowRate;
        in accuracy :> Real;
        out measuredValue :> ISQ::volumeFlowRate;
    }
    
    part def PressureTransmitter {
        attribute transmitterTag :> ScalarValues::String;
        attribute measurementRange :> ISQ::pressure;
        
        port processConnection : FluidPort;
        port signalOutput {
            attribute measuredPressure :> ISQ::pressure;
        }
        
        perform action measurePressure : PressureMeasurement;
    }
    
    action def PressureMeasurement {
        in actualPressure :> ISQ::pressure;
        out measuredValue :> ISQ::pressure;
    }
    
    part def ProcessController {
        attribute controllerTag :> ScalarValues::String;
        attribute targetFlowRate :> ISQ::volumeFlowRate;
        attribute targetDischargePressure :> ISQ::pressure;
        
        port flowInput {
            attribute flowMeasurement :> ISQ::volumeFlowRate;
        }
        
        port pressureInput {
            attribute pressureMeasurement :> ISQ::pressure;
        }
        
        port speedOutput : ControlPort;
        
        perform action controlLogic : AffinityBasedControlStrategy;
    }
    
    action def AffinityBasedControlStrategy {
        in flowSetpoint :> ISQ::volumeFlowRate;
        in pressureSetpoint :> ISQ::pressure;
        in flowMeasurement :> ISQ::volumeFlowRate;
        in pressureMeasurement :> ISQ::pressure;
        in nominalPerformance : PumpPerformanceCurve;
        out speedCommand :> ISQ::angularVelocity;
        out estimatedPower :> ISQ::power;
        
        first start;
        then merge controlLoop;
        
        then action readInputs {
            out currentFlow :> ISQ::volumeFlowRate;
            out currentPressure :> ISQ::pressure;
        }
        
        then action calculateFlowError {
            in setpoint :> ISQ::volumeFlowRate;
            in measurement :> ISQ::volumeFlowRate;
            out error :> ISQ::volumeFlowRate;
        }
        
        then action determineRequiredSpeed {
            in flowError :> ISQ::volumeFlowRate;
            in currentFlow :> ISQ::volumeFlowRate;
            in nominalData : PumpPerformanceCurve;
            out requiredSpeed :> ISQ::angularVelocity;
        }
        
        then action predictPowerConsumption {
            in commandedSpeed :> ISQ::angularVelocity;
            in nominalData : PumpPerformanceCurve;
            out predictedPower :> ISQ::power;
            
            action powerCalculation : CalculatePowerByAffinityLaw3 {
                in referencePower :> ISQ::power;
                in referenceSpeed :> ISQ::angularVelocity;
                in actualSpeed :> ISQ::angularVelocity;
                out actualPower;
            }
        }
        
        then action validateOperatingLimits {
            in proposedSpeed :> ISQ::angularVelocity;
            in proposedPower :> ISQ::power;
            out isAcceptable :> Boolean;
            out limitedSpeed :> ISQ::angularVelocity;
        }
        
        then decide;
            if validateOperatingLimits.isAcceptable then issueCommand;
            if !validateOperatingLimits.isAcceptable then issueLimitedCommand;
        
        action issueCommand {
            in speed :> ISQ::angularVelocity;
            in power :> ISQ::power;
        }
        then controlLoop;
        
        action issueLimitedCommand {
            in speed :> ISQ::angularVelocity;
        }
        then controlLoop;
    }
    
    requirement def AffinityLawSystemRequirements;
    
    requirement <'REQ-AL-001'> flowSpeedProportionality : AffinityLawSystemRequirements {
        doc /* The system shall maintain flow rate proportional to pump speed according to Q2/Q1 = N2/N1 */
        subject pump : CentrifugalPump;
    }
    
    requirement <'REQ-AL-002'> headSpeedSquareRelation : AffinityLawSystemRequirements {
        doc /* The system shall maintain head proportional to square of speed according to H2/H1 = (N2/N1)^2 */
        subject pump : CentrifugalPump;
    }
    
    requirement <'REQ-AL-003'> powerSpeedCubicRelation : AffinityLawSystemRequirements {
        doc /* The system shall maintain power proportional to cube of speed according to P2/P1 = (N2/N1)^3 */
        subject pump : CentrifugalPump;
    }
    
    requirement <'REQ-AL-004'> flowControlAccuracy : AffinityLawSystemRequirements {
        doc /* The system shall maintain flow rate within ±3% of setpoint under steady-state conditions */
    }
    
    requirement <'REQ-AL-005'> energyOptimization : AffinityLawSystemRequirements {
        doc /* The system shall minimize energy consumption by operating pump at optimal speed for required flow */
    }
    
    requirement <'REQ-AL-006'> operatingRangeLimits : AffinityLawSystemRequirements {
        doc /* The system shall operate within safe speed range: 30% to 100% of rated speed */
    }
    
    part affinityLawPumpingSystem {
        doc /* 
            This system demonstrates the application of affinity laws for centrifugal pump control.
            The primary function is to deliver variable flow rates by adjusting pump rotational speed
            while maintaining hydraulic performance relationships defined by affinity laws:
            - Flow varies linearly with speed (Q ∝ N)
            - Head varies with square of speed (H ∝ N²)
            - Power varies with cube of speed (P ∝ N³)
            
            The system uses a variable frequency drive to modulate pump speed based on process
            demand, enabling energy-efficient operation by avoiding throttling losses. A feedback
            control loop continuously monitors flow and pressure, calculating required speed changes
            using affinity law relationships to meet setpoints while predicting power consumption.
        */
        
        satisfy flowSpeedProportionality, headSpeedSquareRelation, powerSpeedCubicRelation,
                flowControlAccuracy, energyOptimization, operatingRangeLimits by self;
        
        part mainPump : CentrifugalPump {
            attribute :>> pumpIdentifier = "P-101";
        }
        
        part motorDrive : VariableFrequencyDrive {
            attribute :>> driveIdentifier = "VFD-101";
            attribute :>> maxFrequency = 60.0 [SI::Hz];
            attribute :>> minFrequency = 18.0 [SI::Hz];
        }
        
        part dischargeFlowMeter : FlowTransmitter {
            attribute :>> transmitterTag = "FT-101";
            attribute :>> measurementAccuracy = 0.5;
        }
        
        part dischargePressureMeter : PressureTransmitter {
            attribute :>> transmitterTag = "PT-101";
            attribute :>> measurementRange = 1000000.0 [SI::Pa];
        }
        
        part suctionPressureMeter : PressureTransmitter {
            attribute :>> transmitterTag = "PT-102";
            attribute :>> measurementRange = 500000.0 [SI::Pa];
        }
        
        part processControl : ProcessController {
            attribute :>> controllerTag = "PIC-101";
            attribute :>> targetFlowRate = 0.12 [SI::'m^3/s'];
            attribute :>> targetDischargePressure = 600000.0 [SI::Pa];
        }
        
        item processFluid : ProcessFluid {
            attribute :>> density = 998.0 [SI::'kg/m^3'];
            attribute :>> viscosity = 0.001002 [SI::'Pa*s'];
            attribute :>> temperature = 293.15 [SI::K];
        }
        
        connect motorDrive.motorOutput to mainPump.shaftPort;
        connect dischargeFlowMeter.processConnection to mainPump.dischargePort;
        connect dischargePressureMeter.processConnection to mainPump.dischargePort;
        connect suctionPressureMeter.processConnection to mainPump.suctionPort;
        connect dischargeFlowMeter.signalOutput.measuredFlow to processControl.flowInput.flowMeasurement;
        connect dischargePressureMeter.signalOutput.measuredPressure to processControl.pressureInput.pressureMeasurement;
        connect processControl.speedOutput to motorDrive.controlInput;
        
        perform action systemOperation : IntegratedPumpingOperation;
    }
    
    action def IntegratedPumpingOperation {
        doc /* 
            Coordinated operation of all system components to achieve flow control
            through affinity law-based speed modulation, demonstrating continuous
            adjustment of pump performance parameters in response to process demands.
        */
        
        first start;
        
        then action initializeSystem {
            out baselineSpeed :> ISQ::angularVelocity;
            out baselinePerformance : PumpPerformanceCurve;
        }
        
        then merge operationCycle;
        
        then action monitorProcess {
            out currentFlowRate :> ISQ::volumeFlowRate;
            out currentDischargePressure :> ISQ::pressure;
            out currentSuctionPressure :> ISQ::pressure;
            out currentPumpSpeed :> ISQ::angularVelocity;
        }
        
        then action executeControl : AffinityBasedControlStrategy {
            in flowSetpoint = 0.12 [SI::'m^3/s'];
            in pressureSetpoint = 600000.0 [SI::Pa];
            in flowMeasurement = monitorProcess.currentFlowRate;
            in pressureMeasurement = monitorProcess.currentDischargePressure;
            in nominalPerformance = initializeSystem.baselinePerformance;
            out speedCommand;
            out estimatedPower;
        }
        
        then action adjustDrive : VFDControlBehavior {
            in speedCommand = executeControl.speedCommand;
            in maxFreq = 60.0 [SI::Hz];
            in minFreq = 18.0 [SI::Hz];
            out motorSpeed;
            out motorTorque;
        }
        
        then action operatePump : PumpHydraulicBehavior {
            in operatingSpeed = adjustDrive.motorSpeed;
            in performanceData = initializeSystem.baselinePerformance;
            out deliveredFlow;
            out developedHead;
            out requiredPower;
        }
        
        then action recordPerformance {
            in actualFlow :> ISQ::volumeFlowRate;
            in actualHead :> ISQ::length;
            in actualPower :> ISQ::power;
            in actualSpeed :> ISQ::angularVelocity;
        }
        
        then operationCycle;
    }
}
