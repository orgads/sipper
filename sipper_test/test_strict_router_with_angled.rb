
require 'driven_sip_test_case'

class TestStrictRouterWithAngled < DrivenSipTestCase

  def setup
    super
    str = <<-EOF
    require 'sip_test_driver_controller'
    
    module SipInline
    
      class UasRs2Controller < SIP::SipTestDriverController
      
        transaction_usage :use_transactions=>true
        
        def on_invite(session)
          logd("Received INVITE in #{name}")
          session.respond_with(200)
        end
        
        def on_ack(session)
          routes = session.irequest.routes
          session.irequest.routes.each do |r|
            session.do_record(r.to_s)
          end
          session.request_with("subscribe")
        end
        
        def on_success_res(session)
          session.invalidate(true) 
          session.flow_completed_for("TestStrictRouterWithAngled")
        end
        
        
        def order
          0
        end
      end
      
      class UacRs2Controller < SIP::SipTestDriverController
      
        transaction_usage :use_transactions=>true
        
        def start
          r = Request.create_initial("invite", "sip:nasir@sipper.com", :p_session_record=>"msg-info",
               :record_route=>"<sip:example1.com>,<sip:example2.com>")
          u = create_udp_session(SipperConfigurator[:LocalSipperIP], SipperConfigurator[:LocalTestPort])
          u.send(r)
          logd("Sent a new INVITE from #{name}")
        end
     
        def on_success_res(session)
          logd("Received response in #{name}")
          session.request_with("ack")
        end
        
        def on_subscribe(session)
          routes = session.irequest.routes
          session.irequest.routes.each do |r|
            session.do_record(r.to_s)
          end
          session.respond_with(200)
          session.invalidate(true)
        end
        
        
      end
    end
    EOF
    define_controller_from(str)
    set_controller("SipInline::UacRs2Controller")
  end
  
  
  def test_rs_controllers
    self.expected_flow = ["> INVITE", "< 100","< 200", "> ACK", "< SUBSCRIBE", "! <sip:127.0.0.1:5066>;transport=UDP", "! <sip:127.0.0.1:5066>", "> 200"]
    start_controller
    verify_call_flow(:out)
    self.expected_flow = ["< INVITE", "> 100", "> 200", "< ACK","! <sip:127.0.0.1:5066>;transport=UDP", "! <sip:127.0.0.1:5066>", "> SUBSCRIBE","< 200"]
    verify_call_flow(:in)
  end
  
end