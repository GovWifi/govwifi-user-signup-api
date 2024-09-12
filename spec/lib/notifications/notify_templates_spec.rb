describe Notifications::NotifyTemplates do
  let(:template_one) { Notifications::NotifyTemplates::TEMPLATES.first }
  let(:template_two) { Notifications::NotifyTemplates::TEMPLATES.last }
  let(:templates) do
    [
      instance_double(Notifications::Client::Template, name: template_one, id: "template_one_id"),
      instance_double(Notifications::Client::Template, name: "unused", id: "unused"),
      instance_double(Notifications::Client::Template, name: template_two, id: "template_two_id"),
    ]
  end
  before do
    template_collection = instance_double(Notifications::Client::TemplateCollection, collection: templates)
    client = instance_double(Notifications::Client, get_all_templates: template_collection)
    allow(Services).to receive(:notify_client).and_return(client)
  end
  describe "#template" do
    it "filters out unused templates" do
      expect { Notifications::NotifyTemplates.template("unused") }.to raise_error(KeyError)
    end
    it "fetches a template" do
      expect(Notifications::NotifyTemplates.template(template_one)).to eq("template_one_id")
      expect(Notifications::NotifyTemplates.template(template_two)).to eq("template_two_id")
    end
    it "accepts symbols" do
      expect(Notifications::NotifyTemplates.template(template_one.to_sym)).to eq("template_one_id")
    end
  end
  describe "#verify_templates" do
    let(:templates) do
      Notifications::NotifyTemplates::TEMPLATES.each_with_index.map do |template, index|
        instance_double(Notifications::Client::Template, name: template, id: index.to_s)
      end
    end
    it "verifies all templates" do
      expect {
        Notifications::NotifyTemplates.verify_templates
      }.to_not raise_error
    end
    it "has a missing template" do
      missing_template = templates.delete_at(0)

      expect {
        Notifications::NotifyTemplates.verify_templates
      }.to raise_error(/Some templates have not been defined in Notify: #{missing_template.name}/)
    end
  end
end
