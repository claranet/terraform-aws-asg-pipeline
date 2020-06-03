from pretf import workflow


def pretf_workflow():
    workflow.require_files("terraform.tfvars")

    workflow.delete_files()
    workflow.delete_links()

    created = workflow.link_files("*.tf", "*.tf.py", "*.tfvars", "*.tfvars.py", "modules")

    return workflow.default(created=created)
