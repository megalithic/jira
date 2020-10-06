defmodule Jira.API do
  defp config_or_env(key, env_var) do
    Application.get_env(:jira, key, System.get_env(env_var))
  end

  defp host do
    config_or_env(:host, "JIRA_HOST")
  end

  defp username do
    config_or_env(:username, "JIRA_USERNAME")
  end

  defp password do
    config_or_env(:password, "JIRA_PASSWORD")
  end

  defp token do
    config_or_env(:token, "JIRA_API_TOKEN")
  end

  ### HTTPoison.Base callbacks
  def process_url(path) do
    host() <> path
  end

  def process_response_body(body) do
    body
    |> decode_body
  end

  def process_request_headers(headers) do
    [{"authorization", authorization_header()} | headers]
  end

  defp decode_body(""), do: ""
  defp decode_body(body), do: Jason.decode!(body)

  ### Internal Helpers
  def authorization_header do
    credentials = encoded_credentials(username(), token())
    "Basic #{credentials}"
  end

  defp encoded_credentials(user, pass) do
    "#{user}:#{pass}"
    |> Base.encode64()
  end

  ### API
  def boards do
    get!("/rest/greenhopper/1.0/rapidview")
  end

  def sprints(board_id) when is_integer(board_id) do
    get!("/rest/greenhopper/1.0/sprintquery/#{board_id}")
  end

  def sprints(%{"id" => board_id}), do: sprints(board_id)

  def sprint_report(board_id, sprint_id) do
    get!(
      "/rest/greenhopper/1.0/rapid/charts/sprintreport?rapidViewId=#{board_id}&sprintId=#{
        sprint_id
      }"
    )
  end

  def ticket_details(key) do
    get!("/rest/api/2/issue/#{key}")
  end

  def add_ticket_link(key, title, link) do
    body = %{"object" => %{"url" => link, "title" => title}} |> Jason.encode!()
    post!("/rest/api/2/issue/#{key}/remotelink", body, [{"Content-type", "application/json"}])
  end

  def add_ticket_watcher(key, username) do
    body = username |> Jason.encode!()
    post!("/rest/api/2/issue/#{key}/watchers", body, [{"Content-type", "application/json"}])
  end

  def search(query) do
    body = query |> Jason.encode!()
    post!("/rest/api/2/search", body, [{"Content-type", "application/json"}])
  end

  def get!(path) do
    {:ok, response} = Mojito.get(process_url(path), process_request_headers([]))

    process_response_body(response.body)
  end

  def post!(path, content, extra_headers) do
    {:ok, response} =
      Mojito.post(process_url(path), process_request_headers(extra_headers), content)

    process_response_body(response.body)
  end
end
