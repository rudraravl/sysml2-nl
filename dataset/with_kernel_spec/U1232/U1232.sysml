package TechnologyReadinessManagement {
	private import ScalarValues::Real;
	private import ScalarValues::Integer;
	private import ScalarValues::String;
	private import ScalarValues::Boolean;
	private import ISQ::TemperatureValue;
	private import ISQ::PowerValue;
	private import ISQ::DurationValue;
	private import SI::K;
	private import SI::W;
	private import SI::h;

	attribute def TRL :> Integer {
		doc
		/*
		 * Technology Readiness Level on a standard scale of 1 to 9.
		 */
		assert constraint { that >= 1 and that <= 9 }
	}

	attribute def Probability :> Real {
		doc
		/*
		 * Probability or ratio value between 0.0 and 1.0 inclusive.
		 */
		assert constraint { that >= 0.0 and that <= 1.0 }
	}

	item def TestCommand {
		attribute directive : String;
	}

	item def TelemetryData {
		attribute temperature : TemperatureValue;
		attribute power : PowerValue;
		attribute reliability : Probability;
		attribute efficiency : Probability;
		attribute currentTRL : TRL;
	}

	item def Measurement {
		attribute observedTemperature : TemperatureValue;
		attribute observedPower : PowerValue;
		attribute observedReliability : Probability;
		attribute observedEfficiency : Probability;
		attribute observedTRL : TRL;
		attribute pass : Boolean;
	}

	item def ReadinessReport {
		attribute assessedTRL : TRL;
		attribute targetTRL : TRL;
		attribute approved : Boolean;
		attribute justification : String;
	}

	port def CommandInPort { in testCommand : TestCommand; }
	port def TestCommandOutPort { out testCommand : TestCommand; }
	port def TelemetryOutPort { out telemetry : TelemetryData; }
	port def TelemetryInPort { in telemetry : TelemetryData; }
	port def MeasurementInPort { in measurement : Measurement; }
	port def MeasurementOutPort { out measurement : Measurement; }
	port def ReportInPort { in report : ReadinessReport; }
	port def ReportOutPort { out report : ReadinessReport; }

	part def PrototypeSubsystem {
		doc
		/*
		 * The actual hardware or software under development and evaluation.
		 * Has defined performance characteristics and can receive commands
		 * and send back status and telemetry data.
		 */
		attribute reliability : Probability;
		attribute efficiency : Probability;
		attribute operatingTemperature : TemperatureValue;
		attribute powerConsumption : PowerValue;
		attribute currentTRL : TRL;
		attribute targetTRL : TRL;

		port commandPort : CommandInPort;
		port telemetryPort : TelemetryOutPort;
	}

	part def TestEnvironment {
		doc
		/*
		 * Simulates the real-world conditions the technology will face,
		 * such as thermal, vibration, or electromagnetic stresses.
		 */
		attribute thermalStress : TemperatureValue;
		attribute vibrationStress : Real;
		attribute testDuration : DurationValue;

		port testCommandPort : TestCommandOutPort;
		port telemetryPort : TelemetryInPort;
		port measurementPort : MeasurementOutPort;

		action conductDemo {
			in prototype : PrototypeSubsystem;
			out measurement : Measurement = new Measurement(
				observedTemperature = prototype.operatingTemperature + thermalStress,
				observedPower = prototype.powerConsumption,
				observedReliability = prototype.reliability,
				observedEfficiency = prototype.efficiency,
				observedTRL = prototype.currentTRL,
				pass = prototype.reliability >= 0.9 and prototype.efficiency >= 0.8
			);
		}
	}

	part def AssessmentAuthority {
		doc
		/*
		 * A Technology Review Board responsible for evaluating test results
		 * and making official maturity decisions.
		 */
		attribute name : String;
		attribute targetTRL : TRL;
		attribute assessedTRL : TRL;

		port measurementPort : MeasurementInPort;
		port decisionPort : ReportOutPort;

		action assess {
			in measurement : Measurement;
			out decision : ReadinessReport = new ReadinessReport(
				assessedTRL = measurement.observedTRL,
				targetTRL = targetTRL,
				approved = measurement.observedTRL >= targetTRL and measurement.pass,
				justification = "Reviewed by " + name + "."
			);
		}
	}

	part def TechnologyReadinessSystem {
		doc
		/*
		 * Overall system managing the cyclic process of demonstration,
		 * assessment, and advancement of technology readiness.
		 */
		attribute targetTRL : TRL;

		part prototype : PrototypeSubsystem {
			attribute :>> targetTRL = targetTRL;
		}
		part testEnvironment : TestEnvironment;
		part authority : AssessmentAuthority {
			attribute :>> targetTRL = targetTRL;
		}

		port systemReportPort : ReportInPort;

		connect testEnvironment.testCommandPort to prototype.commandPort;
		connect prototype.telemetryPort to testEnvironment.telemetryPort;
		connect testEnvironment.measurementPort to authority.measurementPort;
		connect authority.decisionPort to systemReportPort;

		state readinessCycle {
			entry; then demonstrate;
			state demonstrate {
				entry;
				then assess;
			}
			state assess {
				entry;
				then decide;
			}
			state decide {
				if prototype.currentTRL >= targetTRL then ready
				else develop;
			}
			state develop {
				entry assign prototype.currentTRL := prototype.currentTRL + 1;
				then demonstrate;
			}
			state ready;
		}
	}

	requirement def TargetReadinessRequirement {
		doc
		/*
		 * The technology shall achieve its target Technology Readiness Level
		 * before being approved for integration into a larger system.
		 */
		subject prototype : PrototypeSubsystem;
		attribute targetTRL : TRL;
		require constraint { prototype.currentTRL >= targetTRL }
	}

	requirement def PerformanceRequirement {
		doc
		/*
		 * The prototype shall meet minimum performance characteristics
		 * under simulated operational stress.
		 */
		subject prototype : PrototypeSubsystem;
		attribute minReliability : Probability = 0.9;
		attribute minEfficiency : Probability = 0.8;
		attribute maxTemperature : TemperatureValue = 350 [K];
		attribute maxPower : PowerValue = 500 [W];
		require constraint { prototype.reliability >= minReliability }
		require constraint { prototype.efficiency >= minEfficiency }
		require constraint { prototype.operatingTemperature <= maxTemperature }
		require constraint { prototype.powerConsumption <= maxPower }
	}

	verification def TRLVerification {
		doc
		/*
		 * Verification case confirming that the prototype achieves its target TRL.
		 */
		subject prototype : PrototypeSubsystem;
		objective {
			doc
			/*
			 * Confirm the assessed TRL meets or exceeds the target TRL.
			 */
		}
	}

	verification def PerformanceVerification {
		doc
		/*
		 * Verification case confirming that the prototype meets performance
		 * thresholds under simulated stress.
		 */
		subject prototype : PrototypeSubsystem;
		objective {
			doc
			/*
			 * Confirm reliability, efficiency, temperature, and power are within limits.
			 */
		}
	}

	part verificationContext {
		doc
		/*
		 * A specific test scenario in which the TechnologyReadinessSystem
		 * is exercised to verify TRL and performance requirements.
		 */
		part systemUnderTest : TechnologyReadinessSystem {
			attribute :>> targetTRL = 6;
			part :>> prototype {
				attribute :>> reliability = 0.92;
				attribute :>> efficiency = 0.85;
				attribute :>> operatingTemperature = 340 [K];
				attribute :>> powerConsumption = 450 [W];
				attribute :>> currentTRL = 5;
			}
			part :>> testEnvironment {
				attribute :>> thermalStress = 20 [K];
				attribute :>> vibrationStress = 2.0;
				attribute :>> testDuration = 48 [h];
			}
			part :>> authority {
				attribute :>> name = "Technology Review Board";
				attribute :>> targetTRL = 6;
			}
		}
		verification trlCheck : TRLVerification {
			subject = systemUnderTest.prototype;
		}
		verification perfCheck : PerformanceVerification {
			subject = systemUnderTest.prototype;
		}
	}
}
