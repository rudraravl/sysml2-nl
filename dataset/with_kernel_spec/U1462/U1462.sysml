package OrificePlateFlowMeasurementSystem {
    public import Definitions::*;
    public import Usages::*;
    
    package Definitions {
        import ScalarValues::*;
        import ISQ::*;
        import SI::*;
        
        alias Pressure for ISQ::PressureValue;
        alias PressureDiff for ISQ::PressureValue;
        alias Density for ISQ::MassDensityValue;
        alias Viscosity for ISQ::DynamicViscosityValue;
        alias VolFlowRate for ISQ::VolumeFlowRateValue;
        alias MassFlowRate for ISQ::MassFlowRateValue;
        alias Temperature for ISQ::TemperatureValue;
        alias Duration for ISQ::TimeValue;
        alias Current for ISQ::ElectricCurrentValue;
        alias Length for ISQ::LengthValue;
        alias Area for ISQ::AreaValue;
        alias Dimensionless for Real;
        
        attribute def InitComplete;
        attribute def CalComplete;
        attribute def StartMeasurement;
        attribute def StopMeasurement;
        attribute def MaintenanceReq;
        attribute def MaintenanceComplete;
        attribute def FaultDetected;
        attribute def FaultCleared;
        attribute def SystemReady;
        
        item def ProcessFluid {
            attribute density :> Density;
            attribute viscosity :> Viscosity;
            attribute temperature :> Temperature;
        }
        
        item def FlowData {
            attribute volumetricFlowRate :> VolFlowRate;
            attribute massFlowRate :> MassFlowRate;
            attribute timestamp :> Duration;
            attribute valid :> Boolean;
        }
        
        item def CalibrationData {
            attribute dischargeCoefficient : Dimensionless;
            attribute zeroOffset :> PressureDiff;
            attribute span :> PressureDiff;
        }
        
        item def DisplayData {
            attribute volumetricFlowRate :> VolFlowRate;
            attribute massFlowRate :> MassFlowRate;
            attribute status :> String;
        }
        
        port def FluidPort;
        port def PressurePort;
        port def SignalPort;
        port def DataPort;
        port def DisplayPort;
        
        part def Pipeline {
            attribute innerDiameter :> Length;
            attribute length :> Length;
            attribute material :> String;
            port fluidInPort : FluidPort;
            port fluidOutPort : FluidPort;
        }
        
        part def OrificePlate {
            attribute plateThickness :> Length;
            attribute orificeDiameter :> Length;
            attribute pipeDiameter :> Length;
            attribute betaRatio : Dimensionless;
            port fluidInPort : FluidPort;
            port fluidOutPort : FluidPort;
        }
        
        part def PressureTap {
            attribute position :> Length;
            attribute measuredPressure :> Pressure;
            port pressurePort : PressurePort;
        }
        
        part def UpstreamTap :> PressureTap;
        part def DownstreamTap :> PressureTap;
        
        part def DPTransmitter {
            attribute highPressureInput :> Pressure;
            attribute lowPressureInput :> Pressure;
            attribute measuredDiff :> PressureDiff;
            attribute outputCurrent :> Current;
            attribute zeroRange :> PressureDiff;
            attribute fullScaleRange :> PressureDiff;
            port highPressurePort : PressurePort;
            port lowPressurePort : PressurePort;
            port signalPort : SignalPort;
            perform action 'sense pressure difference': 'Sense Pressure Difference';
            perform action 'convert to signal': 'Convert to Signal';
        }
        
        part def FlowComputer {
            attribute dischargeCoefficient : Dimensionless;
            attribute orificeDiameter :> Length;
            attribute pipeDiameter :> Length;
            attribute orificeArea :> Area;
            attribute fluidDensity :> Density;
            attribute fluidViscosity :> Viscosity;
            attribute fluidTemperature :> Temperature;
            attribute expansionFactor : Dimensionless;
            attribute computedVolFlow :> VolFlowRate;
            attribute computedMassFlow :> MassFlowRate;
            attribute reynoldsNumber : Dimensionless;
            port signalPort : SignalPort;
            port dataPort : DataPort;
            port displayPort : DisplayPort;
            perform action 'acquire data': 'Acquire Data';
            perform action 'compute flow rates': 'Compute Flow Rates';
            perform action 'validate results': 'Validate Results';
            perform action 'output flow data': 'Output Flow Data';
            exhibit state 'flow computer states': 'Flow Computer States';
        }
        
        part def FlowConditioner {
            attribute numTubes :> Integer;
            attribute tubeDiameter :> Length;
            attribute length :> Length;
            port fluidInPort : FluidPort;
            port fluidOutPort : FluidPort;
        }
        
        part def FlowIndicator {
            ref item displayData : DisplayData;
            port displayPort : DisplayPort;
        }
        
        part def PlantControlSystem {
            attribute connected :> Boolean;
            port dataPort : DataPort;
        }
        
        part def OrificeFlowMeasurementSystem {
            attribute systemId :> String;
            attribute pipeDiameter :> Length;
            attribute orificeDiameter :> Length;
            attribute betaRatio : Dimensionless;
            attribute designDensity :> Density;
            attribute designViscosity :> Viscosity;
            attribute operatingTemp :> Temperature;
            attribute maxFlowRate :> VolFlowRate;
            attribute minFlowRate :> VolFlowRate;
            attribute maxPressureDiff :> PressureDiff;
            attribute calibrationDueDate :> Duration;
            port fluidInPort : FluidPort;
            port fluidOutPort : FluidPort;
            port dataPort : DataPort;
            port displayPort : DisplayPort;
            perform action 'measure flow': 'Measure Flow';
            perform action 'initialize system': 'Initialize System';
            perform action 'calibrate system': 'Calibrate System';
            exhibit state 'system states': 'System States';
        }
        
        action def 'Sense Pressure Difference' {
            in highPressure : Pressure;
            in lowPressure : Pressure;
            out pressureDiff : PressureDiff;
        }
        
        action def 'Convert to Signal' {
            in pressureDiff : PressureDiff;
            in zeroRange : PressureDiff;
            in fullScaleRange : PressureDiff;
            out signalCurrent : Current;
        }
        
        action def 'Acquire Data' {
            in signalCurrent : Current;
            out pressureDiff : PressureDiff;
            out density : Density;
            out viscosity : Viscosity;
            out temperature : Temperature;
        }
        
        action def 'Compute Flow Rates' {
            in pressureDiff : PressureDiff;
            in density : Density;
            in viscosity : Viscosity;
            in temperature : Temperature;
            in dischargeCoeff : Dimensionless;
            in orificeDiam : Length;
            in pipeDiam : Length;
            in expansionFactor : Dimensionless;
            out volumetricFlow : VolFlowRate;
            out massFlow : MassFlowRate;
            out reynoldsNum : Dimensionless;
        }
        
        action def 'Validate Results' {
            in volumetricFlow : VolFlowRate;
            in massFlow : MassFlowRate;
            in reynoldsNum : Dimensionless;
            out validVolFlow : VolFlowRate;
            out validMassFlow : MassFlowRate;
            out valid : Boolean;
        }
        
        action def 'Output Flow Data' {
            in validVolFlow : VolFlowRate;
            in validMassFlow : MassFlowRate;
            in valid : Boolean;
            out flowData : FlowData;
            out displayData : DisplayData;
        }
        
        action def 'Measure Flow' {
            in signalCurrent : Current;
            out flowData : FlowData;
            out displayData : DisplayData;
        }
        
        action def 'Initialize System' {
            out ready : Boolean;
        }
        
        action def 'Calibrate System' {
            in calibrationData : CalibrationData;
            out calibrated : Boolean;
        }
        
        state def 'System States';
        state def 'Flow Computer States';
        
        requirement def 'Flow Measurement Accuracy' {
            doc /* The system shall measure volumetric flow rate within plus or minus 2 percent of actual flow. */
            subject measuredFlow :> VolFlowRate;
            subject actualFlow :> VolFlowRate;
            constraint {
                measuredFlow >= actualFlow - 0.02 * actualFlow and measuredFlow <= actualFlow + 0.02 * actualFlow
            }
        }
        
        requirement def 'DP Measurement Range' {
            doc /* The DP transmitter shall measure differential pressure within its configured full scale range. */
            subject pressureDiff :> PressureDiff;
            subject maxRange :> PressureDiff;
            constraint {
                pressureDiff <= maxRange
            }
        }
        
        requirement def 'Signal Range' {
            doc /* The output signal shall be in the range of 4 to 20 milliamps. */
            subject outputCurrent :> Current;
            constraint {
                outputCurrent >= 0.004 [A] and outputCurrent <= 0.020 [A]
            }
        }
        
        requirement def 'System Response Time' {
            doc /* The system shall complete one measurement cycle within 1 second. */
            subject responseTime :> Duration;
            constraint {
                responseTime <= 1 [s]
            }
        }
        
        requirement def 'Flow Conditioning Effectiveness' {
            doc /* The flow conditioner shall reduce turbulence to achieve a uniform flow profile. */
            subject swirlAngle : Dimensionless;
            constraint {
                swirlAngle <= 2.0
            }
        }
    }
    
    package Usages {
        private import Definitions::*;
        private import ScalarValues::*;
        private import SI::*;
        
        part 'orificeFlowSystem' : OrificeFlowMeasurementSystem {
            attribute systemId = "OFM-001";
            attribute pipeDiameter = 0.1 [m];
            attribute orificeDiameter = 0.05 [m];
            attribute betaRatio = 0.5;
            attribute designDensity = 998 [kg/m^3];
            attribute designViscosity = 0.001 [Pa*s];
            attribute operatingTemp = 293.15 [K];
            attribute maxFlowRate = 0.01 [m^3/s];
            attribute minFlowRate = 0.0001 [m^3/s];
            attribute maxPressureDiff = 50000 [Pa];
            attribute calibrationDueDate = 31536000 [s];
            
            part 'pipeline' : Pipeline {
                attribute innerDiameter = 0.1 [m];
                attribute length = 5 [m];
                attribute material = "Stainless Steel 316L";
            }
            
            part 'flow conditioner' : FlowConditioner {
                attribute numTubes = 19;
                attribute tubeDiameter = 0.01 [m];
                attribute length = 0.5 [m];
            }
            
            part 'orifice plate' : OrificePlate {
                attribute plateThickness = 0.003 [m];
                attribute orificeDiameter = 0.05 [m];
                attribute pipeDiameter = 0.1 [m];
                attribute betaRatio = 0.5;
            }
            
            part 'upstream tap' : UpstreamTap {
                attribute position = 0.0 [m];
            }
            
            part 'downstream tap' : DownstreamTap {
                attribute position = 0.05 [m];
            }
            
            part 'dp transmitter' : DPTransmitter {
                attribute zeroRange = 0 [Pa];
                attribute fullScaleRange = 50000 [Pa];
            }
            
            part 'flow computer' : FlowComputer {
                attribute dischargeCoefficient = 0.61;
                attribute orificeDiameter = 0.05 [m];
                attribute pipeDiameter = 0.1 [m];
                attribute orificeArea = 0.0019635 [m^2];
                attribute expansionFactor = 1.0;
                attribute fluidDensity = 998 [kg/m^3];
                attribute fluidViscosity = 0.001 [Pa*s];
                attribute fluidTemperature = 293.15 [K];
            }
            
            part 'flow indicator' : FlowIndicator;
            
            part 'plant control' : PlantControlSystem {
                attribute connected = true;
            }
            
            connection 'fluid-in-to-conditioner' connect 'orificeFlowSystem'.fluidInPort to 'flow conditioner'.fluidInPort;
            connection 'conditioner-to-orifice' connect 'flow conditioner'.fluidOutPort to 'orifice plate'.fluidInPort;
            connection 'orifice-to-pipeline' connect 'orifice plate'.fluidOutPort to 'pipeline'.fluidInPort;
            connection 'pipeline-out' connect 'pipeline'.fluidOutPort to 'orificeFlowSystem'.fluidOutPort;
            connection 'upstream-pressure' connect 'upstream tap'.pressurePort to 'dp transmitter'.highPressurePort;
            connection 'downstream-pressure' connect 'downstream tap'.pressurePort to 'dp transmitter'.lowPressurePort;
            connection 'dp-signal' connect 'dp transmitter'.signalPort to 'flow computer'.signalPort;
            connection 'flow-data-to-indicator' connect 'flow computer'.displayPort to 'flow indicator'.displayPort;
            connection 'flow-data-to-control' connect 'flow computer'.dataPort to 'plant control'.dataPort;
            connection 'system-data-out' connect 'flow computer'.dataPort to 'orificeFlowSystem'.dataPort;
            connection 'system-display-out' connect 'flow computer'.displayPort to 'orificeFlowSystem'.displayPort;
        }
        
        action 'measure flow' : 'Measure Flow' {
            in signalCurrent : Current;
            out flowData : FlowData;
            out displayData : DisplayData;
            
            action 'acquire step' : 'Acquire Data' {
                in signalCurrent = 'measure flow'::signalCurrent;
                out pressureDiff : PressureDiff;
                out density : Density;
                out viscosity : Viscosity;
                out temperature : Temperature;
            }
            
            flow 'acquire step'.pressureDiff to 'compute step'.pressureDiff;
            flow 'acquire step'.density to 'compute step'.density;
            flow 'acquire step'.viscosity to 'compute step'.viscosity;
            flow 'acquire step'.temperature to 'compute step'.temperature;
            
            action 'compute step' : 'Compute Flow Rates' {
                in pressureDiff : PressureDiff;
                in density : Density;
                in viscosity : Viscosity;
                in temperature : Temperature;
                in dischargeCoeff : Dimensionless = 0.61;
                in orificeDiam : Length = 0.05 [m];
                in pipeDiam : Length = 0.1 [m];
                in expansionFactor : Dimensionless = 1.0;
                out volumetricFlow : VolFlowRate;
                out massFlow : MassFlowRate;
                out reynoldsNum : Dimensionless;
            }
            
            flow 'compute step'.volumetricFlow to 'validate step'.volumetricFlow;
            flow 'compute step'.massFlow to 'validate step'.massFlow;
            flow 'compute step'.reynoldsNum to 'validate step'.reynoldsNum;
            
            action 'validate step' : 'Validate Results' {
                in volumetricFlow : VolFlowRate;
                in massFlow : MassFlowRate;
                in reynoldsNum : Dimensionless;
                out validVolFlow : VolFlowRate;
                out validMassFlow : MassFlowRate;
                out valid : Boolean;
            }
            
            flow 'validate step'.validVolFlow to 'output step'.validVolFlow;
            flow 'validate step'.validMassFlow to 'output step'.validMassFlow;
            flow 'validate step'.valid to 'output step'.valid;
            
            action 'output step' : 'Output Flow Data' {
                in validVolFlow : VolFlowRate;
                in validMassFlow : MassFlowRate;
                in valid : Boolean;
                out flowData : FlowData;
                out displayData : DisplayData;
            }
            
            flow 'output step'.flowData to 'measure flow'::flowData;
            flow 'output step'.displayData to 'measure flow'::displayData;
        }
        
        state 'system states' : 'System States' parallel {
            state 'Initialization' {
                entry action 'init entry' {
                    /* Perform power-on diagnostics and self-test */
                }
                transition 'init-complete'
                    first 'Initialization'
                    accept InitComplete
                    then 'Calibration';
            }
            
            state 'Calibration' {
                entry action 'cal entry' {
                    /* Calibrate DP transmitter zero and span */
                }
                transition 'cal-complete'
                    first 'Calibration'
                    accept CalComplete
                    then 'Standby';
            }
            
            state 'Standby' {
                entry action 'standby entry' {
                    /* Waiting for measurement command */
                }
                transition 'standby-to-measure'
                    first 'Standby'
                    accept StartMeasurement
                    then 'Measurement Cycle';
                transition 'standby-to-maintenance'
                    first 'Standby'
                    accept MaintenanceReq
                    then 'Maintenance';
            }
            
            state 'Measurement Cycle' {
                entry action 'measure entry' {
                    /* Acquire, compute, validate, and output flow data */
                }
                transition 'measure-to-standby'
                    first 'Measurement Cycle'
                    accept StopMeasurement
                    then 'Standby';
                transition 'measure-to-fault'
                    first 'Measurement Cycle'
                    accept FaultDetected
                    then 'Fault';
            }
            
            state 'Maintenance' {
                entry action 'maintenance entry' {
                    /* Perform scheduled maintenance */
                }
                transition 'maintenance-to-standby'
                    first 'Maintenance'
                    accept MaintenanceComplete
                    then 'Standby';
            }
            
            state 'Fault' {
                entry action 'fault entry' {
                    /* System fault detected - safe shutdown */
                }
                transition 'fault-to-standby'
                    first 'Fault'
                    accept FaultCleared
                    then 'Standby';
            }
        }
        
        state 'flow computer states' : 'Flow Computer States' {
            state 'Initializing' {
                entry action 'fc-init entry' {
                    /* Initialize flow computer */
                }
                transition 'fc-init-to-ready'
                    first 'Initializing'
                    accept SystemReady
                    then 'Ready';
            }
            state 'Ready' {
                entry action 'fc-ready entry' {
                    /* Ready for measurement */
                }
                transition 'fc-ready-to-computing'
                    first 'Ready'
                    accept StartMeasurement
                    then 'Computing';
            }
            state 'Computing' {
                entry action 'fc-compute entry' {
                    /* Continuously computing flow rates */
                }
                transition 'fc-computing-to-ready'
                    first 'Computing'
                    accept StopMeasurement
                    then 'Ready';
            }
        }
    }
}
