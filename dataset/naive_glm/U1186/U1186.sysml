package BiomimeticRoboticFish {
    import ScalarValues::*;
    import ISQ::*;
    
    // ===== Value Types =====
    value type LengthValue = Real { unit = "m"; }
    value type MassValue = Real { unit = "kg"; }
    value type SpeedValue = Real { unit = "m/s"; }
    value type DurationHoursValue = Real { unit = "h"; }
    value type DurationSecondsValue = Real { unit = "s"; }
    value type DepthValue = Real { unit = "m"; }
    value type TemperatureValue = Real { unit = "degC"; }
    value type SalinityValue = Real { unit = "PSU"; }
    value type ChargePercentValue = Real { unit = "%" [min=0, max=100]; }
    value type FrequencyValue = Real { unit = "Hz"; }
    value type AngleValue = Real { unit = "deg"; }
    value type DistanceValue = Real { unit = "m"; }
    value type HeadingValue = Real { unit = "deg"; }
    value type VoltageValue = Real { unit = "V"; }
    value type CurrentValue = Real { unit = "A"; }
    value type ThrustValue = Real { unit = "N"; }
    value type SignalStrengthValue = Real { unit = "dBm"; }
    
    // ===== Item Definitions =====
    item def ProximityReport {
        :>> frontDistance : DistanceValue;
        :>> leftDistance : DistanceValue;
        :>> rightDistance : DistanceValue;
        :>> bottomDistance : DistanceValue;
        :>> timestamp : DurationSecondsValue;
    }
    
    item def DepthReport {
        :>> depth : DepthValue;
        :>> timestamp : DurationSecondsValue;
    }
    
    item def OrientationReport {
        :>> roll : AngleValue;
        :>> pitch : AngleValue;
        :>> yaw : HeadingValue;
        :>> rollRate : Real;
        :>> pitchRate : Real;
        :>> yawRate : Real;
        :>> timestamp : DurationSecondsValue;
    }
    
    item def EnvironmentalSample {
        :>> temperature : TemperatureValue;
        :>> salinity : SalinityValue;
        :>> depth : DepthValue;
        :>> timestamp : DurationSecondsValue;
        :>> sampleId : Integer;
    }
    
    item def TailCommand {
        :>> oscillationFrequency : FrequencyValue;
        :>> amplitude : AngleValue;
        :>> enabled : Boolean;
    }
    
    item def PectoralFinCommand {
        :>> angle : AngleValue;
        :>> oscillationFrequency : FrequencyValue;
        :>> enabled : Boolean;
    }
    
    item def NavigationCommand {
        :>> targetHeading : HeadingValue;
        :>> targetDepth : DepthValue;
        :>> targetSpeed : SpeedValue;
        :>> mode : String;
    }
    
    item def Waypoint {
        :>> latitude : Real;
        :>> longitude : Real;
        :>> depth : DepthValue;
    }
    
    item def MissionCommand {
        :>> missionId : String;
        :>> waypoints : Waypoint[0..*];
        :>> durationLimit : DurationHoursValue;
        :>> priority : Integer;
        :>> timestamp : DurationSecondsValue;
    }
    
    item def SystemStatus {
        :>> batteryLevel : ChargePercentValue;
        :>> depth : DepthValue;
        :>> heading : HeadingValue;
        :>> speed : SpeedValue;
        :>> operationalMode : String;
        :>> timestamp : DurationSecondsValue;
    }
    
    item def TelemetryPacket {
        :>> status : SystemStatus;
        :>> environmentalSamples : EnvironmentalSample[0..*];
        :>> missionId : String;
    }
    
    // ===== Attribute Definitions =====
    attribute maxBodyLength : LengthValue = 0.5;
    attribute bodyMass : MassValue = 3.5;
    attribute maxSpeed : SpeedValue = 1.5;
    attribute maxOperatingDepth : DepthValue = 50;
    attribute missionEndurance : DurationHoursValue = 4;
    attribute lowBatteryThreshold : ChargePercentValue = 20;
    attribute criticalBatteryThreshold : ChargePercentValue = 10;
    attribute obstacleSafeDistance : DistanceValue = 1.0;
    attribute stationKeepingTolerance : DistanceValue = 0.3;
    attribute cruiseTailFrequency : FrequencyValue = 1.5;
    attribute cruiseTailAmplitude : AngleValue = 20;
    attribute maneuverTailFrequency : FrequencyValue = 3.0;
    attribute maneuverTailAmplitude : AngleValue = 35;
    attribute surfaceTailFrequency : FrequencyValue = 0.8;
    attribute surfaceTailAmplitude : AngleValue = 15;
    attribute systemVoltage : VoltageValue = 12.0;
    
    // ===== Port Definitions =====
    port def PowerOutPort {
        out voltage : VoltageValue;
        out current : CurrentValue;
        out chargeLevel : ChargePercentValue;
    }
    
    port def PowerInPort {
        in voltage : VoltageValue;
        in current : CurrentValue;
        in chargeLevel : ChargePercentValue;
    }
    
    port def ProximityOutPort {
        out proximity : ProximityReport;
    }
    
    port def DepthOutPort {
        out depth : DepthReport;
    }
    
    port def IMUOutPort {
        out orientation : OrientationReport;
    }
    
    port def EnvironmentalOutPort {
        out sample : EnvironmentalSample;
    }
    
    port def TailCommandPort {
        in command : TailCommand;
    }
    
    port def PectoralCommandPort {
        in command : PectoralFinCommand;
    }
    
    port def NavigationCommandPort {
        in command : NavigationCommand;
    }
    
    port def TelemetryOutPort {
        out telemetry : TelemetryPacket;
    }
    
    port def MissionInPort {
        in mission : MissionCommand;
    }
    
    port def ChargeReportPort {
        out charge : ChargePercentValue;
    }
    
    port def EmergencySurfacePort {
        out trigger : Boolean;
    }
    
    // ===== Interface Definitions =====
    interface def PowerInterface {
        end supplier : PowerOutPort;
        end consumer : PowerInPort;
        flow from supplier.voltage to consumer.voltage;
        flow from supplier.current to consumer.current;
        flow from supplier.chargeLevel to consumer.chargeLevel;
    }
    
    interface def ProximityDataInterface {
        end source : ProximityOutPort;
        end sink : ProximityReport;
        flow from source.proximity to sink;
    }
    
    interface def DepthDataInterface {
        end source : DepthOutPort;
        end sink : DepthReport;
        flow from source.depth to sink;
    }
    
    interface def IMUDataInterface {
        end source : IMUOutPort;
        end sink : OrientationReport;
        flow from source.orientation to sink;
    }
    
    interface def EnvironmentalDataInterface {
        end source : EnvironmentalOutPort;
        end sink : EnvironmentalSample;
        flow from source.sample to sink;
    }
    
    interface def TailControlInterface {
        end source : TailCommand;
        end sink : TailCommandPort;
        flow from source to sink.command;
    }
    
    interface def PectoralControlInterface {
        end source : PectoralFinCommand;
        end sink : PectoralCommandPort;
        flow from source to sink.command;
    }
    
    interface def TelemetryInterface {
        end source : TelemetryOutPort;
        end sink : TelemetryPacket;
        flow from source.telemetry to sink;
    }
    
    interface def MissionInterface {
        end source : MissionCommand;
        end sink : MissionInPort;
        flow from source to sink.mission;
    }
    
    // ===== Requirements =====
    requirement def PhysicalFormRequirement {
        doc
        subject :>> roboticFish;
        requirement lengthRequirement {
            doc
            subject :>> body;
            :>> maxBodyLength = 0.5;
        }
        requirement massRequirement {
            doc
            subject :>> body;
            :>> bodyMass = 3.5;
        }
    }
    
    requirement def PerformanceRequirement {
        doc
        subject :>> roboticFish;
        requirement maxSpeedRequirement {
            doc
            subject :>> propulsion;
            :>> maxSpeed >= 1.5;
        }
        requirement depthRatingRequirement {
            doc
            subject :>> hull;
            :>> maxOperatingDepth >= 50;
        }
        requirement enduranceRequirement {
            doc
            subject :>> battery;
            :>> missionEndurance >= 4;
        }
    }
    
    requirement def PropulsionRequirement {
        doc
        subject :>> propulsion;
        requirement primaryPropulsionRequirement {
            doc
            subject :>> tail;
            :>> oscillationEnabled = true;
        }
        requirement steeringRequirement {
            doc
            subject :>> pectoralFins;
            :>> independentControl = true;
            :>> finCount = 2;
        }
    }
    
    requirement def AutonomyRequirement {
        doc
        subject :>> controller;
        requirement obstacleAvoidanceRequirement {
            doc
            subject :>> proximitySensor;
            :>> detectionRange >= obstacleSafeDistance;
        }
        requirement depthKeepingRequirement {
            doc
            subject :>> depthSensor;
            :>> maxDepth = maxOperatingDepth;
        }
        requirement orientationTrackingRequirement {
            doc
            subject :>> imu;
            :>> providesRoll = true;
            :>> providesPitch = true;
            :>> providesYaw = true;
        }
    }
    
    requirement def OperationalModesRequirement {
        doc
        subject :>> controller;
        requirement cruiseModeRequirement {
            doc
            :>> cruiseModeEnabled = true;
        }
        requirement maneuverModeRequirement {
            doc
            :>> maneuverModeEnabled = true;
        }
        requirement stationKeepingModeRequirement {
            doc
            :>> stationKeepingEnabled = true;
        }
        requirement surfaceModeRequirement {
            doc
            :>> surfaceModeEnabled = true;
        }
    }
    
    requirement def BatterySafetyRequirement {
        doc
        subject :>> batteryManagement;
        requirement lowBatteryMonitoringRequirement {
            doc
            subject :>> battery;
            :>> continuousMonitoring = true;
        }
        requirement emergencyReturnRequirement {
            doc
            subject :>> controller;
            :>> triggersBelow = lowBatteryThreshold;
        }
        requirement emergencySurfaceRequirement {
            doc
            subject :>> controller;
            :>> triggersBelow = criticalBatteryThreshold;
        }
    }
    
    requirement def CommunicationRequirement {
        doc
        subject :>> communication;
        requirement telemetryTransmissionRequirement {
            doc
            subject :>> transmitter;
            :>> transmitsEnvironmentalData = true;
            :>> transmitsSystemStatus = true;
        }
        requirement missionReceptionRequirement {
            doc
            subject :>> receiver;
            :>> receivesMissionCommands = true;
        }
    }
    
    requirement def EnvironmentalMonitoringRequirement {
        doc
        subject :>> environmentalSensor;
        requirement temperatureMeasurementRequirement {
            doc
            :>> measuresTemperature = true;
        }
        requirement salinityMeasurementRequirement {
            doc
            :>> measuresSalinity = true;
        }
    }
    
    // ===== Part Definitions =====
    
    part def BatteryPack {
        attribute nominalVoltage : VoltageValue = 12.0;
        attribute capacitymAh : Integer = 10000;
        attribute chargeLevel : ChargePercentValue = 100;
        attribute powerOutput : CurrentValue;
        
        port powerOut : PowerOutPort;
        port chargeReport : ChargeReportPort;
        
        action def discharge {
            in loadCurrent : CurrentValue;
            in duration : DurationSecondsValue;
            local chargeConsumed : Real;
            perform {
                chargeConsumed = (loadCurrent * duration / 3600.0) / (capacitymAh / 1000.0) * 100.0;
                chargeLevel = chargeLevel - chargeConsumed;
                if (chargeLevel < 0) then chargeLevel = 0; endif
                powerOut.chargeLevel = chargeLevel;
                chargeReport.charge = chargeLevel;
            }
        }
    }
    
    part def BatteryManagementSystem {
        attribute monitoredCharge : ChargePercentValue;
        attribute monitoringActive : Boolean = true;
        attribute emergencyTriggered : Boolean = false;
        
        port chargeInput : ChargeReportPort;
        port powerInput : PowerInPort;
        port emergencySignal : EmergencySurfacePort;
        
        action def monitorCharge {
            in charge : ChargePercentValue;
            perform {
                monitoredCharge = charge;
                if (charge <= lowBatteryThreshold && charge > criticalBatteryThreshold) then {
                    perform returnToSurface();
                endif
                if (charge <= criticalBatteryThreshold) then {
                    emergencySignal.trigger = true;
                    perform emergencySurface();
                endif
            }
        }
        
        action def returnToSurface {
            perform {
                emergencySignal.trigger = true;
            }
        }
        
        action def emergencySurface {
            perform {
                emergencySignal.trigger = true;
            }
        }
    }
    
    part def ProximitySensor {
        attribute sensingRange : DistanceValue = 2.0;
        attribute samplingRate : FrequencyValue = 10;
        
        port proximityOut : ProximityOutPort;
        port powerIn : PowerInPort;
        
        action def senseObstacles {
            local front : DistanceValue;
            local left : DistanceValue;
            local right : DistanceValue;
            local bottom : DistanceValue;
            local report : ProximityReport;
            perform {
                front = perform measureDistance(direction="front");
                left = perform measureDistance(direction="left");
                right = perform measureDistance(direction="right");
                bottom = perform measureDistance(direction="bottom");
                report.frontDistance = front;
                report.leftDistance = left;
                report.rightDistance = right;
                report.bottomDistance = bottom;
                report.timestamp = 0;
                proximityOut.proximity = report;
            }
        }
        
        action measureDistance {
            in direction : String;
            return distance : DistanceValue;
        }
    }
    
    part def DepthSensor {
        attribute maxRange : DepthValue = 100;
        attribute accuracy : DepthValue = 0.1;
        attribute samplingRate : FrequencyValue = 20;
        
        port depthOut : DepthOutPort;
        port powerIn : PowerInPort;
        
        action def measureDepth {
            local measuredDepth : DepthValue;
            local report : DepthReport;
            perform {
                measuredDepth = perform readPressureAndConvert();
                report.depth = measuredDepth;
                report.timestamp = 0;
                depthOut.depth = report;
            }
        }
        
        action readPressureAndConvert {
            return depth : DepthValue;
        }
    }
    
    part def InertialMeasurementUnit {
        attribute samplingRate : FrequencyValue = 100;
        attribute rollCalibration : AngleValue = 0;
        attribute pitchCalibration : AngleValue = 0;
        attribute yawCalibration : HeadingValue = 0;
        
        port imuOut : IMUOutPort;
        port powerIn : PowerInPort;
        
        action def measureOrientation {
            local roll : AngleValue;
            local pitch : AngleValue;
            local yaw : HeadingValue;
            local rollRate : Real;
            local pitchRate : Real;
            local yawRate : Real;
            local report : OrientationReport;
            perform {
                roll = perform readAccelerometer(axis="roll");
                pitch = perform readAccelerometer(axis="pitch");
                yaw = perform readMagnetometer();
                rollRate = perform readGyroscope(axis="roll");
                pitchRate = perform readGyroscope(axis="pitch");
                yawRate = perform readGyroscope(axis="yaw");
                report.roll = roll;
                report.pitch = pitch;
                report.yaw = yaw;
                report.rollRate = rollRate;
                report.pitchRate = pitchRate;
                report.yawRate = yawRate;
                report.timestamp = 0;
                imuOut.orientation = report;
            }
        }
        
        action readAccelerometer {
            in axis : String;
            return angle : AngleValue;
        }
        
        action readGyroscope {
            in axis : String;
            return rate : Real;
        }
        
        action readMagnetometer {
            return heading : HeadingValue;
        }
    }
    
    part def EnvironmentalSensorPackage {
        attribute temperatureRangeMin : TemperatureValue = -5;
        attribute temperatureRangeMax : TemperatureValue = 50;
        attribute salinityRangeMin : SalinityValue = 0;
        attribute salinityRangeMax : SalinityValue = 80;
        attribute samplingInterval : DurationSecondsValue = 5;
        
        port envOut : EnvironmentalOutPort;
        port powerIn : PowerInPort;
        port depthInput : DepthDataPort;
        
        action def collectEnvironmentalData {
            local temp : TemperatureValue;
            local sal : SalinityValue;
            local depth : DepthValue;
            local sample : EnvironmentalSample;
            local sampleCount : Integer = 0;
            perform {
                temp = perform measureTemperature();
                sal = perform measureSalinity();
                depth = perform readDepthFromPort();
                sampleCount = sampleCount + 1;
                sample.temperature = temp;
                sample.salinity = sal;
                sample.depth = depth;
                sample.timestamp = 0;
                sample.sampleId = sampleCount;
                envOut.sample = sample;
            }
        }
        
        action measureTemperature {
            return temp : TemperatureValue;
        }
        
        action measureSalinity {
            return sal : SalinityValue;
        }
        
        action readDepthFromPort {
            return depth : DepthValue;
        }
    }
    
    part def TailPropulsionUnit {
        attribute maxFrequency : FrequencyValue = 5.0;
        attribute maxAmplitude : AngleValue = 45;
        attribute currentFrequency : FrequencyValue;
        attribute currentAmplitude : AngleValue;
        attribute enabled : Boolean = false;
        
        port commandInput : TailCommandPort;
        port powerIn : PowerInPort;
        
        action def oscillate {
            in command : TailCommand;
            perform {
                currentFrequency = command.oscillationFrequency;
                currentAmplitude = command.amplitude;
                enabled = command.enabled;
                perform generateThrust(
                    frequency=currentFrequency,
                    amplitude=currentAmplitude
                );
            }
        }
        
        action generateThrust {
            in frequency : FrequencyValue;
            in amplitude : AngleValue;
            local thrust : ThrustValue;
            perform {
                thrust = frequency * amplitude * 0.05;
            }
        }
    }
    
    part def PectoralFin {
        attribute side : String;
        attribute maxAngle : AngleValue = 60;
        attribute currentAngle : AngleValue = 0;
        attribute oscillationFrequency : FrequencyValue = 0;
        attribute enabled : Boolean = false;
        
        port commandInput : PectoralCommandPort;
        port powerIn : PowerInPort;
        
        action def actuate {
            in command : PectoralFinCommand;
            perform {
                currentAngle = command.angle;
                oscillationFrequency = command.oscillationFrequency;
                enabled = command.enabled;
                perform controlSurface(angle=currentAngle);
            }
        }
        
        action controlSurface {
            in angle : AngleValue;
        }
    }
    
    part def NavigationController {
        attribute currentMode : String = "Cruise";
        attribute targetDepth : DepthValue = 5;
        attribute targetHeading : HeadingValue = 0;
        attribute targetSpeed : SpeedValue = 0.5;
        attribute currentDepth : DepthValue;
        attribute currentHeading : HeadingValue;
        attribute currentCharge : ChargePercentValue;
        attribute missionActive : Boolean = false;
        attribute stationTimer : DurationSecondsValue = 0;
        
        port proximityInput : ProximityDataPort;
        port depthInput : DepthDataPort;
        port imuInput : IMUDataPort;
        port environmentalInput : EnvironmentalDataPort;
        port chargeInput : ChargeReportPort;
        port emergencyInput : EmergencySurfacePort;
        port missionInput : MissionInPort;
        port tailCommandOut : TailCommand;
        port leftPectoralCommandOut : PectoralFinCommand;
        port rightPectoralCommandOut : PectoralFinCommand;
        port telemetryOut : TelemetryOutPort;
        port powerIn : PowerInPort;
        
        state def NavigationStateMachine {
            attribute mode : String;
            
            state Cruise {
                entry {
                    mode = "Cruise";
                    tailCommandOut.oscillationFrequency = cruiseTailFrequency;
                    tailCommandOut.amplitude = cruiseTailAmplitude;
                    tailCommandOut.enabled = true;
                    leftPectoralCommandOut.angle = 0;
                    leftPectoralCommandOut.oscillationFrequency = 0;
                    leftPectoralCommandOut.enabled = false;
                    rightPectoralCommandOut.angle = 0;
                    rightPectoralCommandOut.oscillationFrequency = 0;
                    rightPectoralCommandOut.enabled = false;
                }
                do {
                    perform processSensorData();
                    perform maintainHeading();
                    perform maintainDepth();
                    perform transmitTelemetry();
                }
                exit {
                    perform logModeTransition(from="Cruise");
                }
            }
            
            state Maneuver {
                entry {
                    mode = "Maneuver";
                    tailCommandOut.oscillationFrequency = maneuverTailFrequency;
                    tailCommandOut.amplitude = maneuverTailAmplitude;
                    tailCommandOut.enabled = true;
                }
                do {
                    perform processSensorData();
                    perform avoidObstacle();
                    perform adjustHeading();
                    perform transmitTelemetry();
                }
                exit {
                    perform logModeTransition(from="Maneuver");
                }
            }
            
            state StationKeeping {
                entry {
                    mode = "StationKeeping";
                    tailCommandOut.oscillationFrequency = 0.5;
                    tailCommandOut.amplitude = 5;
                    tailCommandOut.enabled = true;
                    stationTimer = 0;
                }
                do {
                    perform processSensorData();
                    perform holdPosition();
                    perform collectDetailedSample();
                    perform transmitTelemetry();
                    stationTimer = stationTimer + 1;
                }
                exit {
                    perform logModeTransition(from="StationKeeping");
                }
            }
            
            state Surface {
                entry {
                    mode = "Surface";
                    tailCommandOut.oscillationFrequency = surfaceTailFrequency;
                    tailCommandOut.amplitude = surfaceTailAmplitude;
                    tailCommandOut.enabled = true;
                    targetDepth = 0;
                }
                do {
                    perform processSensorData();
                    perform ascend();
                    perform transmitTelemetry();
                    perform checkSurfaced();
                }
                exit {
                    perform logModeTransition(from="Surface");
                }
            }
            
            transition from Cruise to Maneuver
                when proximityInput.frontDistance < obstacleSafeDistance;
            
            transition from Maneuver to Cruise
                when proximityInput.frontDistance >= obstacleSafeDistance
                    && proximityInput.leftDistance >= obstacleSafeDistance
                    && proximityInput.rightDistance >= obstacleSafeDistance;
            
            transition from Cruise to StationKeeping
                when missionActive == true && targetSpeed == 0;
            
            transition from Maneuver to StationKeeping
                when missionActive == true && targetSpeed == 0
                    && proximityInput.frontDistance >= obstacleSafeDistance;
            
            transition from StationKeeping to Cruise
                when missionActive == false || targetSpeed > 0;
            
            transition from Cruise to Surface
                when chargeInput.charge <= lowBatteryThreshold;
            
            transition from Maneuver to Surface
                when chargeInput.charge <= lowBatteryThreshold;
            
            transition from StationKeeping to Surface
                when chargeInput.charge <= lowBatteryThreshold;
            
            transition from any to Surface
                when emergencyInput.trigger == true;
        }
        
        action processSensorData {
            perform {
                currentDepth = depthInput.depth.value;
                currentHeading = imuInput.orientation.yaw;
                currentCharge = chargeInput.charge;
            }
        }
        
        action maintainHeading {
            local headingError : HeadingValue;
            local correction : AngleValue;
            perform {
                headingError = targetHeading - currentHeading;
                if (headingError > 5) then {
                    correction = 10;
                    leftPectoralCommandOut.angle = correction;
                    rightPectoralCommandOut.angle = -correction;
                    leftPectoralCommandOut.enabled = true;
                    rightPectoralCommandOut.enabled = true;
                elif (headingError < -5) then {
                    correction = -10;
                    leftPectoralCommandOut.angle = correction;
                    rightPectoralCommandOut.angle = -correction;
                    leftPectoralCommandOut.enabled = true;
                    rightPectoralCommandOut.enabled = true;
                else {
                    leftPectoralCommandOut.angle = 0;
                    rightPectoralCommandOut.angle = 0;
                    leftPectoralCommandOut.enabled = false;
                    rightPectoralCommandOut.enabled = false;
                endif
            }
        }
        
        action maintainDepth {
            local depthError : DepthValue;
            perform {
                depthError = targetDepth - currentDepth;
                if (depthError > stationKeepingTolerance) then {
                    perform descend(amount=depthError);
                elif (depthError < -stationKeepingTolerance) then {
                    perform ascend(amount=-depthError);
                endif
            }
        }
        
        action avoidObstacle {
            local leftClear : DistanceValue;
            local rightClear : DistanceValue;
            perform {
                leftClear = proximityInput.leftDistance;
                rightClear = proximityInput.rightDistance;
                if (leftClear > rightClear) then {
                    perform turnLeft();
                else
                    perform turnRight();
                endif
            }
        }
        
        action turnLeft {
            perform {
                leftPectoralCommandOut.angle = -30;
                rightPectoralCommandOut.angle = 30;
                leftPectoralCommandOut.enabled = true;
                rightPectoralCommandOut.enabled = true;
            }
        }
        
        action turnRight {
            perform {
                leftPectoralCommandOut.angle = 30;
                rightPectoralCommandOut.angle = -30;
                leftPectoralCommandOut.enabled = true;
                rightPectoralCommandOut.enabled = true;
            }
        }
        
        action adjustHeading {
            perform maintainHeading();
        }
        
        action holdPosition {
            perform {
                tailCommandOut.oscillationFrequency = 0.3;
                tailCommandOut.amplitude = 3;
                leftPectoralCommandOut.angle = 0;
                rightPectoralCommandOut.angle = 0;
                leftPectoralCommandOut.oscillationFrequency = 2;
                rightPectoralCommandOut.oscillationFrequency = 2;
                leftPectoralCommandOut.enabled = true;
                rightPectoralCommandOut.enabled = true;
                perform maintainDepth();
            }
        }
        
        action collectDetailedSample {
            perform {
                perform collectHighResolutionSample();
            }
        }
        
        action collectHighResolutionSample {
            local detailedSample : EnvironmentalSample;
            perform {
                detailedSample = environmentalInput.sample;
                detailedSample.sampleId = detailedSample.sampleId + 100000;
            }
        }
        
        action ascend {
            in amount : DepthValue = 0;
            perform {
                targetDepth = 0;
                tailCommandOut.oscillationFrequency = surfaceTailFrequency;
                tailCommandOut.amplitude = surfaceTailAmplitude;
                leftPectoralCommandOut.angle = 20;
                rightPectoralCommandOut.angle = 20;
                leftPectoralCommandOut.enabled = true;
                rightPectoralCommandOut.enabled = true;
            }
        }
        
        action descend {
            in amount : DepthValue;
            perform {
                leftPectoralCommandOut.angle = -20;
                rightPectoralCommandOut.angle = -20;
                leftPectoralCommandOut.enabled = true;
                rightPectoralCommandOut.enabled = true;
            }
        }
        
        action checkSurfaced {
            perform {
                if (currentDepth < 1) then {
                    missionActive = false;
                    tailCommandOut.enabled = false;
                endif
            }
        }
        
        action transmitTelemetry {
            local telemetry : TelemetryPacket;
            local status : SystemStatus;
            perform {
                status.batteryLevel = currentCharge;
                status.depth = currentDepth;
                status.heading = currentHeading;
                status.speed = targetSpeed;
                status.operationalMode = currentMode;
                status.timestamp = 0;
                telemetry.status = status;
                telemetry.missionId = "current";
                telemetryOut.telemetry = telemetry;
            }
        }
        
        action logModeTransition {
            in from : String;
        }
    }
    
    part def CommunicationModule {
        attribute transmissionRate : FrequencyValue = 0.1;
        attribute signalStrength : SignalStrengthValue;
        attribute connected : Boolean = false;
        
        port telemetryIn : TelemetryOutPort;
        port missionOut : MissionInPort;
        port telemetryOut : TelemetryOutPort;
        port powerIn : PowerInPort;
        
        action def transmitData {
            local packet : TelemetryPacket;
            perform {
                packet = telemetryIn.telemetry;
                perform encodeAndTransmit(packet=packet);
            }
        }
        
        action encodeAndTransmit {
            in packet : TelemetryPacket;
            local encoded : String;
            perform {
                encoded = perform serialize(packet);
                perform sendRadio(data=encoded);
            }
        }
        
        action serialize {
            in packet : TelemetryPacket;
            return data : String;
        }
        
        action sendRadio {
            in data : String;
        }
        
        action def receiveMission {
            local mission : MissionCommand;
            perform {
                mission = perform decodeMission();
                missionOut.mission = mission;
            }
        }
        
        action decodeMission {
            return mission : MissionCommand;
        }
    }
    
    part def BaseStation {
        attribute stationId : String = "Base-01";
        attribute receivedSamples : EnvironmentalSample[0..*];
        attribute currentMissions : MissionCommand[0..*];
        
        port telemetryIn : TelemetryOutPort;
        port missionOut : MissionInPort;
        
        action def receiveTelemetry {
            local packet : TelemetryPacket;
            perform {
                packet = telemetryIn.telemetry;
                perform archiveData(packet);
            }
        }
        
        action archiveData {
            in packet : TelemetryPacket;
            perform {
                receivedSamples = receivedSamples.concat(packet.environmentalSamples);
            }
        }
        
        action def dispatchMission {
            in mission : MissionCommand;
            perform {
                missionOut.mission = mission;
            }
        }
    }
    
    part def Hull {
        attribute length : LengthValue = maxBodyLength;
        attribute mass : MassValue = bodyMass;
        attribute depthRating : DepthValue = maxOperatingDepth;
        attribute pressureHullRating : Real;
    }
    
    // ===== System Composition =====
    
    part def BiomimeticRoboticFishSystem {
        part hull : Hull;
        part battery : BatteryPack;
        part batteryManagement : BatteryManagementSystem;
        part navigationController : NavigationController;
        part proximitySensor : ProximitySensor;
        part depthSensor : DepthSensor;
        part imu : InertialMeasurementUnit;
        part environmentalSensor : EnvironmentalSensorPackage;
        part tailPropulsion : TailPropulsionUnit;
        part leftPectoralFin : PectoralFin {
            attribute side = "left";
        }
        part rightPectoralFin : PectoralFin {
            attribute side = "right";
        }
        part communicationModule : CommunicationModule;
        
        // Power distribution
        connection powerFromBatteryToBMS : PowerInterface connect battery.powerOut to batteryManagement.powerInput;
        connection powerFromBatteryToNav : PowerInterface connect battery.powerOut to navigationController.powerIn;
        connection powerFromBatteryToProximity : PowerInterface connect battery.powerOut to proximitySensor.powerIn;
        connection powerFromBatteryToDepth : PowerInterface connect battery.powerOut to depthSensor.powerIn;
        connection powerFromBatteryToIMU : PowerInterface connect battery.powerOut to imu.powerIn;
        connection powerFromBatteryToEnv : PowerInterface connect battery.powerOut to environmentalSensor.powerIn;
        connection powerFromBatteryToTail : PowerInterface connect battery.powerOut to tailPropulsion.powerIn;
        connection powerFromBatteryToLeftPectoral : PowerInterface connect battery.powerOut to leftPectoralFin.powerIn;
        connection powerFromBatteryToRightPectoral : PowerInterface connect battery.powerOut to rightPectoralFin.powerIn;
        connection powerFromBatteryToComm : PowerInterface connect battery.powerOut to communicationModule.powerIn;
        
        // Battery management charge monitoring
        connection batteryChargeToBMS : PowerInterface connect battery.powerOut to batteryManagement.powerInput;
        connection chargeReportToBMS connect battery.chargeReport to batteryManagement.chargeInput;
        connection chargeReportToNav connect battery.chargeReport to navigationController.chargeInput;
        
        // Emergency surface signal
        connection emergencyFromBMS connect batteryManagement.emergencySignal to navigationController.emergencyInput;
        
        // Sensor data to navigation controller
        connection proximityToNav connect proximitySensor.proximityOut to navigationController.proximityInput;
        connection depthToNav connect depthSensor.depthOut to navigationController.depthInput;
        connection imuToNav connect imu.imuOut to navigationController.imuInput;
        connection envToNav connect environmentalSensor.envOut to navigationController.environmentalInput;
        
        // Depth to environmental sensor (for sampling)
        connection depthToEnv connect depthSensor.depthOut to environmentalSensor.depthInput;
        
        // Navigation controller commands to actuators
        connection tailCommandFromNav connect navigationController.tailCommandOut to tailPropulsion.commandInput;
        connection leftPectoralCommandFromNav connect navigationController.leftPectoralCommandOut to leftPectoralFin.commandInput;
        connection rightPectoralCommandFromNav connect navigationController.rightPectoralCommandOut to rightPectoralFin.commandInput;
        
        // Communication module
        connection telemetryFromNavToComm connect navigationController.telemetryOut to communicationModule.telemetryIn;
        connection telemetryFromCommToNav connect communicationModule.telemetryOut to navigationController.telemetryInput;
        connection missionFromCommToNav connect communicationModule.missionOut to navigationController.missionInput;
    }
    
    part def FieldOperationsSetup {
        part roboticFish : BiomimeticRoboticFishSystem;
        part baseStation : BaseStation;
        
        connection telemetryFromFishToBase connect roboticFish.communicationModule.telemetryOut to baseStation.telemetryIn;
        connection missionFromBaseToFish connect baseStation.missionOut to roboticFish.communicationModule.missionOut;
    }
    
    // ===== Requirement Satisfaction =====
    satisfaction satisfyPhysicalForm : PhysicalFormRequirement {
        subject :>> roboticFish = FieldOperationsSetup.roboticFish;
        :>> body = FieldOperationsSetup.roboticFish.hull;
    }
    
    satisfaction satisfyPerformance : PerformanceRequirement {
        subject :>> roboticFish = FieldOperationsSetup.roboticFish;
        :>> propulsion = FieldOperationsSetup.roboticFish.tailPropulsion;
        :>> hull = FieldOperationsSetup.roboticFish.hull;
        :>> battery = FieldOperationsSetup.roboticFish.battery;
    }
    
    satisfaction satisfyPropulsion : PropulsionRequirement {
        subject :>> propulsion = FieldOperationsSetup.roboticFish.tailPropulsion;
        :>> tail = FieldOperationsSetup.roboticFish.tailPropulsion;
        :>> pectoralFins = FieldOperationsSetup.roboticFish.leftPectoralFin;
    }
    
    satisfaction satisfyAutonomy : AutonomyRequirement {
        subject :>> controller = FieldOperationsSetup.roboticFish.navigationController;
        :>> proximitySensor = FieldOperationsSetup.roboticFish.proximitySensor;
        :>> depthSensor = FieldOperationsSetup.roboticFish.depthSensor;
        :>> imu = FieldOperationsSetup.roboticFish.imu;
    }
    
    satisfaction satisfyOperationalModes : OperationalModesRequirement {
        subject :>> controller = FieldOperationsSetup.roboticFish.navigationController;
    }
    
    satisfaction satisfyBatterySafety : BatterySafetyRequirement {
        subject :>> batteryManagement = FieldOperationsSetup.roboticFish.batteryManagement;
        :>> battery = FieldOperationsSetup.roboticFish.battery;
        :>> controller = FieldOperationsSetup.roboticFish.navigationController;
    }
    
    satisfaction satisfyCommunication : CommunicationRequirement {
        subject :>> communication = FieldOperationsSetup.roboticFish.communicationModule;
        :>> transmitter = FieldOperationsSetup.roboticFish.communicationModule;
        :>> receiver = FieldOperationsSetup.roboticFish.communicationModule;
    }
    
    satisfaction satisfyEnvironmentalMonitoring : EnvironmentalMonitoringRequirement {
        subject :>> environmentalSensor = FieldOperationsSetup.roboticFish.environmentalSensor;
    }
}
