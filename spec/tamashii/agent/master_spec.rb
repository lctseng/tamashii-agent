require 'spec_helper'

RSpec.describe Tamashii::Agent::Master do


  let(:serv_host) { "manager.dev" }
  let(:serv_port) { 3000 }
  let(:serial_number) { "Test" }

  let(:ev_type) { 1 }
  let(:ev_body) { "ABC" }
  let(:event) { Tamashii::Agent::Event.new(ev_type, ev_body) }

  let!(:component_instance) do
    obj = double()
    allow(obj).to receive(:run)
    allow(obj).to receive(:stop)
    allow(obj).to receive(:send_event)
    obj
  end

  let(:ivar_components) { subject.instance_variable_get(:@components) }

  subject { described_class.new(serv_host, serv_port) }

  shared_examples "broadcast to components" do |arg_event|
    it "let all component receive same events" do
      expect(component_instance).to have_received(:send_event).with(arg_event).exactly(ivar_components.size).times
    end
  end

  before do
    allow_any_instance_of(described_class).to receive(:create_component).and_return(component_instance)
  end

  describe "#initialize" do
    before do 
      allow_any_instance_of(described_class).to receive(:get_serial_number).and_return(serial_number)
    end

    it 'creates all components' do
      expect_any_instance_of(described_class).to receive(:create_component).with(Tamashii::Agent::Connection, any_args)
      expect_any_instance_of(described_class).to receive(:create_component).with(Tamashii::Agent::Buzzer, any_args)
      expect_any_instance_of(described_class).to receive(:create_component).with(Tamashii::Agent::CardReader, any_args)
      subject
    end

    it 'should gather its serial number' do
      expect(subject.serial_number).to eq serial_number
    end
  end

  describe "#create_component" do
    it "create a component and return it" do
      dummy_class = double()
      expect(subject.create_component(dummy_class)).to be component_instance
    end
  end

  describe "#process event" do
    let(:master_only_events) { [Tamashii::Agent::Event::SYSTEM_COMMAND] }
    context "when the message should handle by master" do
      it "does not pass this event to any compoments" do
        expect(component_instance).not_to receive(:send_event)
        expect(subject).not_to receive(:broadcast_event).with(Tamashii::Agent::Event.new(ev_type, ev_body))
        master_only_events.each do |ev_type|
          subject.process_event(Tamashii::Agent::Event.new(ev_type, ev_body))
        end
      end
    end

    context "when the connection is not ready" do
      before do
        subject.process_event(Tamashii::Agent::Event.new(Tamashii::Agent::Event::CONNECTION_NOT_READY, "ABC"))
      end
      it_behaves_like "broadcast to components", Tamashii::Agent::Event.new(Tamashii::Agent::Event::BEEP, "error")
    end

    context "when the message is not recognized" do
      let(:component_instance) { spy('component') }
      before do 
        subject.process_event(Tamashii::Agent::Event.new(987654321, "ABC"))
      end
      it_behaves_like "broadcast to components", Tamashii::Agent::Event.new(987654321, "ABC")
    end
  end

  describe "#stop" do
    it "stops all components" do
      expect(component_instance).to receive(:stop).exactly(ivar_components.size).times
      subject.stop
    end
  end
end
